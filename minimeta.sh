#!/bin/zsh

source ~/.zshrc

name=$1
diff <(xml_grep /feed/entry/title ${name}-python.xml | grep -v 'file filename') <(xml_grep /feed/entry/title ${name}-perl.xml | grep -v 'file filename')
