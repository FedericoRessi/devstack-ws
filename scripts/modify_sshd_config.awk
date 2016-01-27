#!/usr/bin/awk -f

/^ClientAliveInterval / {$0="--cut here--"}
/^TCPKeepAlive /        {$0="--cut here--"}
/^ClientAliveCountMax / {$0="--cut here--"}
!/^--cut here--$/{print $0}

END {
    print "";
    print "# Disable ssh connection timeout";
    print "ClientAliveInterval 30";
    print "TCPKeepAlive yes";
    print "ClientAliveCountMax 99999";
}
