#!/bin/zsh

source ~/.zshrc

diff <(xml_grep /feed/entry/title python.xml | grep -v 'file filename') <(xml_grep /feed/entry/title perl.xml | grep -v 'file filename')
