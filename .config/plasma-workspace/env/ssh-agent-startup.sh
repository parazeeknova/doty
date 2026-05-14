#!/bin/sh
[ -n "$SSH_AGENT_PID" ] || eval "$(ssh-agent -s)"
export SSH_ASKPASS=/usr/bin/ksshaskpass
export SSH_ASKPASS_REQUIRE=prefer
