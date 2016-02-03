import collections
import logging
import os
import six
import sys

import yaml
from zuul.lib import cloner


LOG = logging.getLogger(__name__)

commands = {}


def main(argv):
    if argv:
        command = commands.get(argv[0], invalid_command)
    else:
        command = invalid_command
    setup_logging()
    conf = Configuration.from_file('ws.yaml')
    return command(argv, conf)


def command(func):
    commands[func.__name__.replace('_', '-')] = func
    return func


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
        try:
            return self[name]
        except KeyError:
            raise AttributeError 


@command
def get_sources(argv, conf):
    for zuul_source in conf.sources.zuul:
        branch = zuul_source.get('branch', 'master')
        zuul_cloner(
            git_base_url=zuul_source.git_base_url or\
                'https://git.openstack.org/',
            branch=branch,
            projects=[p.project for p in zuul_source.projects],
            workspace=zuul_source.get('workspace'),
            cache_dir=zuul_source.get('cache-dir'),
            project_branches=[
                p.get('branch', branch)
                for p in zuul_source.projects])
    return 0

def zuul_cloner(
         git_base_url, projects, workspace=None, zuul_branch=None,
         zuul_ref=None, zuul_url=None, branch='master', clone_map_file=None,
         project_branches=None, cache_dir=None):
    c = cloner.Cloner(
        git_base_url=git_base_url,
        projects=projects,
        workspace=workspace or os.getcwd(),
        zuul_branch=zuul_branch or os.environ.get('ZUUL_BRANCH'),
        zuul_ref=zuul_ref or os.environ.get('ZUUL_REF'),
        zuul_url=zuul_url or os.environ.get('ZUUL_URL'),
        branch=branch,
        clone_map_file=clone_map_file,
        project_branches=project_branches or ['master'] * len(projects),
        cache_dir=cache_dir or os.environ.get('ZUUL_CACHE_DIR'))
    return c.execute()

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
