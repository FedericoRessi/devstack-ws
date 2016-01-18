#!/usr/bin/env python

from contextlib import contextmanager
import datetime
import logging
import os
from os import path
import re
import sys
import time

from ansi2html import Ansi2HTMLConverter
import sh

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
    log_file_name_format = '{timestamp}_{log_name}.raw'
    log_path = None

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
            sh.tail('-n', '100', self.log_path, _out=sys.stderr)

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
                    file_handler = logging.FileHandler(log_path, 'wt')
                    file_handler.setLevel(logging.DEBUG)
                    file_handler.setFormatter(formatter)
                    root.addHandler(file_handler)
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

            if log_path:
                with open(log_path, 'rb') as ansi_log:
                    ansi = ansi_log.read()

                new_log_path = os.path.splitext(log_path)[0] +\
                    '_' + self.status

                # write txt file without colors
                with open(new_log_path + '.txt', 'wb') as ascii_file:
                    ascii = re.compile(r'\x1b[^m]*m').sub('', ansi)
                    ascii_file.write(ascii)

                # write html file with colors
                converter = Ansi2HTMLConverter(dark_bg=True, scheme='xterm')
                html = converter.convert(ansi.decode('utf-8'))
                with open(new_log_path + '.html', 'wb') as html_file:
                    html_file.write(html.encode('utf-8'))


if __name__ == '__main__':
    exit(execute(sys.argv[1:]))
