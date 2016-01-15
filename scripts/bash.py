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

logger = logging.getLogger(__name__)


def bash(*argv):
    logging.getLogger('sh').setLevel(logging.WARNING)
    return Bash().execute(argv)


class Bash(object):

    timestamp_format = '%y-%m-%d_%H:%M:%S'
    log_format = '%(asctime)-15s | %(message)s'
    log_dir = os.environ.get('LOG_DIR') or path.join(os.getcwd(), 'logs')
    log_file_name_format = '{timestamp}_{log_name}.raw'

    def __init__(self):
        self.output_logger = logging.getLogger('out')
        self.error_logger = logging.getLogger('err')

    def execute(self, argv):
        log_name = argv[-1].split('#', 1)[-1].strip().strip()

        with self.use_logging(log_name) as log_path:
            command_line = ' '.join("'" + arg + "'" for arg in argv)
            logger.debug('Begin executing commmand: %s', command_line)

            self.status = "EXECUTING"
            self.log_path = log_path
            self.exit_code = None

            try:
                sh.bash('-x', *argv,
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
                logger.exception('Internal error.')

            except BaseException:
                exit_code = 1
                severity = logging.WARNING
                status = "INTERRUPTED"

            else:
                exit_code = 0
                status = 'SUCCESS'
                severity = logging.INFO

            self.exit_code = exit_code
            self.status = status

            LOG.debug(
                severity,
                'Finished executing command:\n'
                '    Command line: %s\n'
                '    Status: %s\n'
                '    Exit code: %s\n'
                '    Log file: %s\n',
                command_line, status, exit_code, log_path)

            logger.info(status)

        if exit_code != 0:
            if log_path:
                sh.tail('-n', '100', log_path, _out=sys.stderr)

        if log_path:
            with open(log_path, 'rb') as ansi_log:
                ansi = ansi_log.read()

            new_log_path = os.path.splitext(log_path)[0] + '_' + status

            # write txt file without colors
            with open(new_log_path + '.txt', 'wb') as ascii_file:
                ascii = re.compile(r'\x1b[^m]*m').sub('', ansi)
                ascii_file.write(ascii)

            # write html file with colors
            converter = Ansi2HTMLConverter(dark_bg=True, scheme='xterm')
            html = converter.convert(ansi.decode('utf-8'))
            with open(new_log_path + '.html', 'wb') as html_file:
                html_file.write(html.encode('utf-8'))

        return exit_code

    def write_stdout(self, msg):
        self.output_logger.info(msg[:-1])

    def write_stderr(self, msg):
        self.error_logger.info(msg[:-1])

    def new_log_path(self, log_name):
        timestamp = datetime.datetime.now().strftime(self.timestamp_format)
        log_file_name = self.log_file_name_format.format(
            timestamp=timestamp, log_name=log_name)
        return path.join(self.log_dir, log_file_name)

    @contextmanager
    def use_logging(self, log_name, level=logging.WARNING):
        logging._acquireLock()
        try:
            root = logging.root
            if len(root.handlers) == 0:
                root.setLevel(logging.DEBUG)

                formatter = logging.Formatter(self.log_format)

                stream_handler = logging.StreamHandler()
                stream_handler.setLevel(level)
                stream_handler.setFormatter(formatter)
                root.addHandler(stream_handler)

                log_path = self.new_log_path(log_name)
                while path.isfile(log_path):
                    time.sleep(.1)
                    log_path = self.new_log_path(log_name)

                if path.isdir(path.dirname(log_path)):
                    file_handler = logging.FileHandler(log_path, 'wt')
                    file_handler.setLevel(logging.INFO)
                    file_handler.setFormatter(formatter)
                    root.addHandler(file_handler)
                else:
                    log_path = None
                    file_handler = None
        finally:
            logging._releaseLock()

        try:
            yield log_path

        finally:
            if file_handler:
                file_handler.close()


if __name__ == '__main__':
    logger = logging.getLogger('bash')
    exit(bash(*sys.argv[1:]))
