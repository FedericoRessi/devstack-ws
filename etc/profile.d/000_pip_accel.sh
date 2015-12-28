PIP_ACCEL=$(which pip-accel 2>/dev/null || true)
if [ -x $PIP_ACCEL ]; then
    alias sudo='sudo '
    alias pip="echo Y | $PIP_ACCEL"
    alias pip2="echo Y | $PIP_ACCEL"
    alias pip2.7="echo Y | $PIP_ACCEL"
fi
