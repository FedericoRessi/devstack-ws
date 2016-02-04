import collections
import contextlib
import logging
import os
import six
import sys

import sh
import yaml
from zuul.lib import cloner
from git_review import cmd as git_review


LOG = logging.getLogger(__name__)

commands = {}


def main(argv):
    if argv:
        command = commands.get(argv[0], invalid_command)
    else:
        command = invalid_command
    setup_logging()
    conf = Configuration.from_file('ws.yaml')
    command(argv, conf)
    return 0


def command(func):
    commands[func.__name__.replace('_', '-')] = func
    return func


@command
def get_sources(argv, conf):
    for source in conf.sources:
        cl = cloner.Cloner(
            git_base_url=source.git_base_url,
            projects=list(source.projects),
            branch=source.branch,
            zuul_branch=source.zuul_branch,
            zuul_ref=source.zuul_ref,
            zuul_url=source.zuul_url,
            workspace=source.workspace or os.getcwd(),
            clone_map_file='',
            project_branches={
                project_name: project.branch
                for project_name, project in six.iteritems(source.projects)
                if project.branch},
            cache_dir=source.cache_dir)
        cl.execute()

        for project_name, project in six.iteritems(source.projects):
            with cd(project_name):
                change = project.gerrit_change
                if change:
                    print 'change:', change
                    try:
                        git.remote.remove('gerrit')
                    except sh.ErrorReturnCode_1:
                        pass
                    gitreview('-d', str(change))

                for name, url in six.iteritems(project.get('remotes', {})):
                    try:
                        git.remote('add', name, url)
                    except sh.ErrorReturnCode_1:
                        git.remote('set-url', name, url)
                    git.fetch(name)

                rebase = project.rebase
                if rebase:
                    print 'rebase:', rebase
                    git.rebase(rebase)


git = sh.git.bake('--no-pager')


@contextlib.contextmanager
def cd(directory):
    cwd = os.getcwd()
    os.chdir(directory)
    try:
        yield
    finally:
        os.chdir(cwd)


def gitreview(*argv):
    old_argv = sys.argv
    sys.argv = ['git-review'] + list(argv)
    try:
        return git_review._main()
    finally:
        sys.argv = old_argv
        # shutil.rmtree(temp_dir)


class Configuration(dict):

    @classmethod
    def from_file(cls, filename):
        if filename.endswith('yaml'):
            with open(filename, 'rt') as stream:
                return cls.from_yaml(stream)

    @classmethod
    def from_yaml(cls, stream):
        Loader = getattr(yaml, 'CLoader', None) or getattr(yaml, 'Loader')
        return cls.from_data(yaml.load(stream, Loader=Loader))

    @classmethod
    def from_data(cls, data):
        if isinstance(data, collections.Mapping):
            return cls.from_mapping(data)
        elif isinstance(data, list):
            return cls.from_sequence(data)
        else:
            return data

    @classmethod
    def from_mapping(cls, data):
        return cls(
            ((name, cls.from_data(value))
             for name, value in six.iteritems(data)))

    @classmethod
    def from_sequence(cls, data):
        return [cls.from_data(value) for value in data]

    def __getattr__(self, name):
        return self.get(name)


def setup_logging(color=False, verbose=False):
    """Cloner logging does not rely on conf file"""
    if verbose:
        logging.basicConfig(level=logging.DEBUG)
    else:
        logging.basicConfig(level=logging.INFO)

    if color:
        # Color codes http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/x329.html
        logging.addLevelName(  # cyan
            logging.DEBUG, "\033[36m%s\033[0m" %
            logging.getLevelName(logging.DEBUG))
        logging.addLevelName(  # green
            logging.INFO, "\033[32m%s\033[0m" %
            logging.getLevelName(logging.INFO))
        logging.addLevelName(  # yellow
            logging.WARNING, "\033[33m%s\033[0m" %
            logging.getLevelName(logging.WARNING))
        logging.addLevelName(  # red
            logging.ERROR, "\033[31m%s\033[0m" %
            logging.getLevelName(logging.ERROR))
        logging.addLevelName(  # red background
            logging.CRITICAL, "\033[41m%s\033[0m" %
            logging.getLevelName(logging.CRITICAL))


def invalid_command(argv, conf):
    LOG.error("Invalid command: %s", argv)
    return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
