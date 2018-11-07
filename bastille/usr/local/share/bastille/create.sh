#!/bin/sh
# 
# Copyright (c) 2018, Christer Edwards <christer.edwards@gmail.com>
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# 
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# 
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

. /usr/local/share/bastille/colors.pre.sh
. /usr/local/etc/bastille/bastille.conf

usage() {
    echo -e "${COLOR_RED}Usage: bastille create name release ip.${COLOR_RESET}"
    exit 1
}

running_jail() {
    jls -N name | grep ${NAME}
}

validate_ip() {
    ip=${IP}
    
    if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
      IFS=.
      set $ip
      for quad in 1 2 3 4; do
        if eval [ \$$quad -gt 255 ]; then
          echo "fail ($ip)"
          exit 1
        fi
      done
      echo -e "${COLOR_GREEN}Valid: ($ip).${COLOR_RESET}"
    else
      exit 1
    fi
}

create_jail() {
    bastille_jail_base="${bastille_jailsdir}/${NAME}/root/.bastille"  ## dir
    bastille_jail_template="${bastille_jailsdir}/${NAME}/root/.template"  ## dir
    bastille_jail_path="${bastille_jailsdir}/${NAME}/root"  ## dir
    bastille_jail_fstab="${bastille_jailsdir}/${NAME}/fstab"  ## file
    bastille_jail_conf="${bastille_jailsdir}/${NAME}/jail.conf"  ## file
    bastille_jail_log="${bastille_logsdir}/${NAME}_console.log"  ## file
    bastille_jail_rc_conf="${bastille_jailsdir}/${NAME}/root/etc/rc.conf.local" ## file
    bastille_jail_resolv_conf="${bastille_jailsdir}/${NAME}/root/etc/resolv.conf" ## file

    if [ ! -d "${bastille_jail_base}" ]; then
        mkdir -p "${bastille_jail_base}"
        mkdir -p "${bastille_jail_path}/usr"
        mkdir -p "${bastille_jail_path}/usr/home"
    fi

    if [ ! -d "${bastille_jail_template}" ]; then
        mkdir -p "${bastille_jail_template}"
    fi

    if [ ! -f "${bastille_jail_fstab}" ]; then
        echo -e "${bastille_releasesdir}/${RELEASE} ${bastille_jail_base} nullfs ro 0 0" > ${bastille_jail_fstab}
    fi

    if [ ! -f "${bastille_jail_conf}" ]; then
	echo -e "interface = lo1;\nhost.hostname = ${NAME};\nexec.consolelog =\
	${bastille_jail_log};\npath = ${bastille_jail_path};\nip6 =\
	disable;\nsecurelevel = 2;\ndevfs_ruleset = 4;\nenforce_statfs =\
	2;\nexec.start = '/bin/sh /etc/rc';\nexec.stop = '/bin/sh\
	/etc/rc.shutdown';\nexec.clean;\nmount.devfs;\nmount.fstab =\
	${bastille_jail_fstab};\n\n${NAME} {\n\tip4.addr = ${IP};\n}" >\
	${bastille_jail_conf}
    fi

    ## using relative paths here
    ## MAKE SURE WE'RE IN THE RIGHT PLACE
    ## ro
    cd "${bastille_jail_path}"
    echo
    echo -e "${COLOR_GREEN}RELEASE: ${RELEASE}.${COLOR_RESET}"
    echo -e "${COLOR_GREEN}NAME: ${NAME}.${COLOR_RESET}"
    echo -e "${COLOR_GREEN}IP: ${IP}.${COLOR_RESET}"
    echo

    for _link in bin boot lib libexec rescue sbin usr/bin usr/include usr/lib usr/lib32 usr/libdata usr/libexec usr/sbin usr/share usr/src; do
        ln -sf /.bastille/${_link} ${_link}
    done

    ## link home properly
    ln -sf usr/home home

    ## rw
    cp -a "${bastille_releasesdir}/${RELEASE}/.cshrc" "${bastille_jail_path}"
    cp -a "${bastille_releasesdir}/${RELEASE}/.profile" "${bastille_jail_path}"
    cp -a "${bastille_releasesdir}/${RELEASE}/COPYRIGHT" "${bastille_jail_path}"
    cp -a "${bastille_releasesdir}/${RELEASE}/dev" "${bastille_jail_path}"
    cp -a "${bastille_releasesdir}/${RELEASE}/etc" "${bastille_jail_path}"
    cp -a "${bastille_releasesdir}/${RELEASE}/media" "${bastille_jail_path}"
    cp -a "${bastille_releasesdir}/${RELEASE}/mnt" "${bastille_jail_path}"
    if [ "${RELEASE}" == "11.2-RELEASE" ]; then cp -a "${bastille_releasesdir}/${RELEASE}/net" "${bastille_jail_path}"; fi
    cp -a "${bastille_releasesdir}/${RELEASE}/proc" "${bastille_jail_path}"
    cp -a "${bastille_releasesdir}/${RELEASE}/root" "${bastille_jail_path}"
    cp -a "${bastille_releasesdir}/${RELEASE}/tmp" "${bastille_jail_path}"
    cp -a "${bastille_releasesdir}/${RELEASE}/var" "${bastille_jail_path}"
    cp -a "${bastille_releasesdir}/${RELEASE}/usr/obj" "${bastille_jail_path}"
    if [ "${RELEASE}" == "11.2-RELEASE" ]; then cp -a "${bastille_releasesdir}/${RELEASE}/usr/tests" "${bastille_jail_path}"; fi

    ## rc.conf.local & resolv.conf
    if [ ! -f "${bastille_jail_rc_conf}" ]; then
        echo -e "syslogd_flags=\"-ss\"\nsendmail_enable=\"NONE\"" > ${bastille_jail_rc_conf}
    fi

    if [ ! -f "${bastille_jail_resolv_conf}" ]; then
        echo -e "nameserver 1.1.1.1\nnameserver 1.0.0.1\noptions edns0 rotate" > ${bastille_jail_resolv_conf}
    fi

    ## TZ: UTC
    ln -s "/usr/share/zoneinfo/Etc/UTC ${bastille_jail_root}/etc/localtime"
    ln -s "/.template/usr/local ${bastille_jail_root}/usr/local"
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    usage
    ;;
esac

if [ $# -gt 3 ] || [ $# -lt 3 ]; then
    usage
fi

NAME="$1"
RELEASE="$2"
IP="$3"

## verify release
case "${RELEASE}" in
10.4-RELEASE)
    RELEASE="10.4-RELEASE"
    ;;
11.2-RELEASE)
    RELEASE="11.2-RELEASE"
    ;;
*)
    echo -e "${COLOR_RED}Unknown Release.${COLOR_RESET}"
    usage
    ;;
esac

## check for name/root/.bastille
if [ -d "/usr/local/bastille/jails/${NAME}/root/.bastille" ]; then
    echo -e "${COLOR_RED}Jail: ${NAME} already created. ${NAME}/root/.bastille exists.${COLOR_RESET}"
    exit 1
fi

## check for name/root/.template
if [ -d "/usr/local/bastille/jails/${NAME}/root/.template" ]; then
    echo -e "${COLOR_RED}Jail: ${NAME} already created. ${NAME}/root/.template exists.${COLOR_RESET}"
    exit 1
fi

## check if a running jail matches name
if running_jail ${NAME}; then
    echo -e "${COLOR_RED}Running jail matches name.${COLOR_RESET}"
    exit 1
fi

## check if ip address is valid
if ! validate_ip ${IP}; then
    echo -e "${COLOR_RED}Invalid: ($ip).${COLOR_RESET}"
fi

create_jail ${NAME} ${RELEASE} ${IP}
