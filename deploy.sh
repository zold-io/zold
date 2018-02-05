#!/bin/bash
set -e

cd $(dirname $0)
bundle update
rake
trap 'git reset HEAD~1 && git checkout -- .gitignore' EXIT
sed -i -s 's|Gemfile.lock||g' .gitignore
git add Gemfile.lock
git add .gitignore
git commit -m 'configs for heroku'
git push heroku master -f

