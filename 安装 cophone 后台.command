#!/bin/zsh
cd -- "${0:A:h}"
python3 ios6/deploy.py --voice
result=$?
read "reply?按回车关闭此窗口。"
exit $result
