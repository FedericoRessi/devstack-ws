#!/usr/bin/env python

from contextlib import contextmanager
import datetime
import glob
import logging
import os
from os import path
import Queue
import re
import sys
import time

import ansi2html
import sh
import six


LOG = logging.getLogger('bash')


def execute(command_line, repeat=1, log_name=None):

    command_line = list(command_line)

    log_level = logging.WARNING

    for arg in list(command_line[:-1]):
        if arg.startswith('--repeat='):
            repeat = arg.split('=')[1].strip()
            command_line.remove(arg)

        elif arg.startswith('--log-name='):
            log_name = arg.split('=')[1].strip()
            command_line.remove(arg)

        elif arg == '-v':
            log_level -= 10
            command_line.remove(arg)

        elif arg == '-q':
            log_level += 10
            command_line.remove(arg)

    if log_name is None and command_line:
        log_name = command_line[-1].split(
            '#', 1)[-1].strip().split(' ')[0].strip()

    return Bash(log_name=log_name, log_level=log_level).execute(
        command_line, repeat=int(repeat))


class Bash(object):

    timestamp_format = '%Y-%m-%d_%H:%M:%S'
    log_format = '%(asctime)-15s | %(message)s'
    log_dir = os.environ.get('LOG_DIR') or path.join(os.getcwd(), 'logs')
    log_file_name_format = '{timestamp}_{log_name}_RUNNING'
    log_path = None
    status = 'BEGIN'

    def __init__(self, log_name=None, log_level=logging.WARNING):
        self.log_name = log_name
        self.log_level = log_level

    def execute(self, command_line, repeat=1):
        with self.use_logging():
            for i in range(repeat):
                if repeat > 1:
                    LOG.debug('Execution #%d of %d', i + 1, repeat)

                result = self._execute(command_line)
                if result != 0 and repeat > 1:
                    LOG.error('Failed after %d executions.', i + 1)
                    return result
            return result

    def _execute(self, command_line):
        LOG.debug(
            'Begin executing commmand: %s',
            ' '.join("'" + arg + "'" for arg in command_line))

        self.status = "EXECUTING"
        self.exit_code = None

        try:
            sh.bash('-x', *command_line,
                    _out=self.write_stdout,
                    _err=self.write_stderr)

        except sh.ErrorReturnCode as error:
            exit_code = error.exit_code
            status = "FAILED"
            severity = logging.ERROR

        except Exception:
            exit_code = 1
            status = "ERROR"
            severity = logging.ERROR
            LOG.exception('Internal error.')

        except BaseException:
            exit_code = 1
            severity = logging.WARNING
            status = "INTERRUPTED"

        else:
            exit_code = 0
            status = 'SUCCESS'
            severity = logging.DEBUG

        self.exit_code = exit_code
        self.status = status

        if exit_code != 0 and self.log_level < logging.ERROR:
            stream = sys.stderr
            stream.write('=' * 79 + '\n')
            sh.tail('-n', '100', self.log_path + '.ansi', _out=stream)
            stream.write('=' * 79 + '\n')

        LOG.log(
            severity,
            'Finished executing command:\n'
            '    Command line: %s\n'
            '    Status: %s\n'
            '    Exit code: %s\n'
            '    Log file: %s\n',
            command_line, status, exit_code, self.log_path)

        return exit_code

    def write_stdout(self, msg):
        self._write_message(msg, logger=self.output_logger)

    def write_stderr(self, msg):
        self._write_message(msg, logger=self.error_logger)

    def _write_message(self, msg, logger):
        msg = msg[:-1]
        today = datetime.datetime.now().strftime('%Y-%m-%d')
        while msg.startswith(today):
            msg = msg.split(' ', 2)[-1]
            if msg.startswith('| '):
                msg = msg[2:]
        if msg.startswith('+'):
            LOG.info(msg)
        else:
            logger.debug(msg)

    def new_log_path(self):
        timestamp = datetime.datetime.now().strftime(self.timestamp_format)
        self.log_file_name = log_file_name = self.log_file_name_format.format(
            timestamp=timestamp, log_name=self.log_name)
        return path.join(self.log_dir, log_file_name)

    @contextmanager
    def use_logging(self):
        logging._acquireLock()
        try:
            root = logging.root
            if len(root.handlers) == 0:
                root.setLevel(logging.DEBUG)
                logging.getLogger('sh').setLevel(logging.WARNING)

                formatter = logging.Formatter(self.log_format)

                stream_handler = logging.StreamHandler()
                stream_handler.setLevel(self.log_level)
                stream_handler.setFormatter(formatter)
                LOG.addHandler(stream_handler)

                log_path = self.new_log_path()
                while path.isfile(log_path):
                    time.sleep(.1)
                    log_path = self.new_log_path()

                if path.isdir(path.dirname(log_path)):
                    file_handler = logging.FileHandler(log_path + '.ansi', 'wt')
                    file_handler.setLevel(logging.DEBUG)
                    file_handler.setFormatter(formatter)
                    root.addHandler(file_handler)

                    html_handler = HtmlFileHandler(log_path + '.html', 'wt')
                    html_handler.setLevel(logging.DEBUG)
                    html_handler.setFormatter(formatter)
                    root.addHandler(html_handler)

                    txt_handler = TxtFileHandler(log_path + '.txt', 'wt')
                    txt_handler.setLevel(logging.DEBUG)
                    txt_handler.setFormatter(formatter)
                    root.addHandler(txt_handler)

                else:
                    log_path = None
                    file_handler = None
                self.log_path = log_path
        finally:
            self.output_logger = logging.getLogger('out')
            self.error_logger = logging.getLogger('err')
            logging._releaseLock()

        try:
            yield log_path

        finally:
            if file_handler:
                file_handler.close()
            if html_handler:
                html_handler.close()
            if txt_handler:
                html_handler.close()

            if log_path:
                for file_name in glob.glob(log_path + '.*'):
                    new_file_name = file_name.replace(
                        '_RUNNING.', '_' + self.status + '.')
                    os.rename(file_name, new_file_name)


class HtmlFileHandler(logging.FileHandler):
    """
    A handler class which writes formatted logging records to disk files.
    """

    def _open(self):
        output = super(HtmlFileHandler, self)._open()
        input = Ansi2HtmlStream(output)
        input.open()
        return input


class TxtFileHandler(logging.FileHandler):
    """
    A handler class which writes formatted logging records to disk files.
    """

    ansi_to_txt = re.compile(r'\x1b[^m]*m').sub

    def emit(self, record):
        record.msg = self.ansi_to_txt('', record.msg)
        return super(TxtFileHandler, self).emit(record)


_html_header = six.u(
"""
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=%(output_encoding)s">
<title>%(title)s</title>
<style type="text/css">\n%(style)s\n</style>
</head>
<body class="body_foreground body_background" bgcolor="#FFFFFF" style="font-size: %(font_size)s;" >
<pre class="ansi2html-content">
""")


_html_footer = six.u(
"""
</pre>
</body>
</html>
""")


class Ansi2HtmlStream(object):

    HEADER = _html_header
    FOOTER = _html_footer
    Ansi2HTMLConverter = ansi2html.Ansi2HTMLConverter
    scheme = "xterm"

    def __init__(self, stream, ensure_trailing_newline=False, converter=None):
        self.stream = stream
        if not converter:
            converter = self.Ansi2HTMLConverter()
        self.converter = converter
        self.ensure_trailing_newline = ensure_trailing_newline

    def open(self):
        return self.stream.write(
            self.HEADER % {
            'style' : "\n".join(
                str(s)
                for s in ansi2html.style.get_styles(
                    self.converter.dark_bg, self.scheme)),
            'title' : self.converter.title,
            'font_size' : self.converter.font_size,
            'output_encoding' : self.converter.output_encoding})
        self._indent += 1
        return self

    def write(self, ansi):
        html = self.converter.convert(
            ansi, full=False,
            ensure_trailing_newline=self.ensure_trailing_newline)
        return self.stream.write(html)

    def flush(self):
        self.stream.flush()

    def close(self):
        self.stream.write(self.FOOTER)
        self.stream.close()

    _indent = 0

    def __enter__(self):
        if self._indent < 1:
            self.open()
            self.indent = 1
        else:
            self._indent += 1
        return self

    def __exit__(self, arg):
        if self._indent > 1:
            self._indent -= 1
        else:
            self.close()
            self.indent = 0

if __name__ == '__main__':
    exit(execute(sys.argv[1:]))
