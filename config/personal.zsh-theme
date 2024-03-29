#!/bin/zsh
# Prompt format:
#
# A series of info, each with a specfic color, and seperated by triangles
#
# Configured by $PERSONAL_PROMPT_STRING, formatted as
# '(color)key>'...
# Each section is seperated by a `>`, and has the color specified by (color).
# Color is passed (unmodified) to %K{} and %F{}
# `\n` ends the current line, and inserts a literal newline into the prompt
# `>` is expanded to be a trangle, using the approprate colors
# `<` is expanded similarly
# key is one of the following:
#   `$`...: a literal shell function or command
#   `%`...: a literal prompt expansion
#   username: the username of the current user
#   date`(format)`?: the date, followed by an optional format
#
#
# $psvar is used to add specfic parameters to the final prompt

# User > DIR > git >
# status <
#SEPER=$'\ue0b0'
#SEP() {
   #echo -n "%K{$2}%F{$1}\ue0b0%f"
#}

# precmd() {
   ## Executed before prompt. Gaurenteed to only execute once
   ## Init prompt vars
   #local git=$($HOME/bin/install/pretty-git-prompt/target/release/pretty-git-prompt -c $HOME/bin/config/pretty-git-prompt-zsh.yml)
   #local venv=$(get_venv_name_prompt)
   #export psvar=($git $venv)
# }

#PROMPT=''
#PROMPT+="%K{237}%F{223} %n "
#PROMPT+="%1(j.$(SEP 237 214)%F{237} %%%j "
#PROMPT+="$(SEP 214 208).$(SEP 237 208))%F{237} !%! "
#PROMPT+="$(SEP 208 109)%F{237} %4~ "
#PROMPT+="$(SEP 109 142)%F{237}%1v"
#PROMPT+="$(SEP 142 72)%2v"
#PROMPT+="$(SEP 72 0)"
#PROMPT+='
#'
#PROMPT+="%K{241} %(?.%F{250}√.%F{88}%?) %F{0}$(echo -n '\ue0b2')%k%f%(!.#.) "

# strategy: eval the result of a rust program

if [[ ! -x $HOME/bin/install/zsh-theme/target/debug/zsh-theme ]]
then
   if [[ ! -d $HOME/bin/install/zsh-theme ]]
   then
      cd $HOME/bin/install
      git clone https://github.com/the10thWiz/zsh-theme.git
   else
      cd $HOME/bin/install
      git pull
   fi
   cd $HOME/bin/install/zsh-theme
   cargo build
fi

GIT_PROMPT_GEN() {
   if [[ -z $GIT_PROMPT_DISABLE ]]; then
      $HOME/bin/install/pretty-git-prompt/target/release/pretty-git-prompt -c $HOME/bin/config/pretty-git-prompt-zsh.yml
   else
      echo $GIT_PROMPT_DISABLE
   fi
}

DOCKER_NUM() {
   if [[ -d '/var/run/docker.sock' ]]
   then
      N="$(docker ps | tail -n +2 | wc -l)"
      if [[ $N != "0" ]]
      then
         echo "D[$N]"
      else
         echo ""
      fi
   else
      echo ""
   fi
}

GIT_REMOTE_URL() {
   if [[ -z $GIT_PROMPT_DISABLE ]]
   then
      $HOME/bin/install/git-remote-url/target/release/git-remote-url
   fi
}

HOSTNAME="@$(hostname)"
if [[ "$HOSTNAME" == "@matthew-ubuntu" ]]
then
   HOSTNAME=""
elif [[ "$HOSTNAME" =~ "@WINDOWS-*" ]]
then
   HOSTNAME="@wsl"
fi

set_title() {
   title "${HOSTNAME#@}:$(print -P '%4~')"
}

TEST_PROMPT='(237;223)%n$HOSTNAME$(set_title)>'
TEST_PROMPT+='(214)?1j;%%%j>'
TEST_PROMPT+='(208;237)!%!>'
TEST_PROMPT+='(109;237)%2~>'
TEST_PROMPT+='(142;237)?$(GIT_PROMPT_GEN)>'
TEST_PROMPT+='(72;237)?$(get_venv_name_prompt)>'
TEST_PROMPT+='(109;237)?$(DOCKER_NUM)>'
TEST_PROMPT+='(72;237)?$(battery_pct)>' # TODO: test this with an actual battery
TEST_PROMPT+='(208;237)%D %T>'
TEST_PROMPT+='(~)\n|(237)??;%F{250}  √;%F{88}%?|(237;250) $(vi_mode_prompt_info)<'
#TEST_PROMPT+='(~)%-1&gt;&gt;$(GIT_REMOTE_URL)%&gt;&gt;|(~)\n|(237)??;%F{250}  √;%F{88}%?|(237;250) $(vi_mode_prompt_info)<'
TEST_PROMPT+='(0)%k%f %(!.#.)'

TMP=$($HOME/bin/install/zsh-theme/target/debug/zsh-theme $TEST_PROMPT )
for L in $TMP; do
   eval $L
done

RPROMPT=''

#printf '%s' $($HOME/bin/install/zsh-theme/target/debug/zsh-theme $TEST_PROMPT )

