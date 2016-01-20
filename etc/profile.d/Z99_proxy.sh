GIT_PROXY_WRAPPER="${GIT_PROXY_COMMAND:-/etc/default/git_proxy_wrapper}"
if [ -x "$GIT_PROXY_WRAPPER" ]; then
    export GIT_PROXY_COMMAND="${GIT_PROXY_COMMAND:-$GIT_PROXY_WRAPPER}"
fi

export no_proxy="$(/etc/default/get_no_proxy || echo $no_proxy)"
