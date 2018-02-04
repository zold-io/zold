#!/bin/bash
set -e

cd $(dirname $0)
bundle update
rake
sed -i -s 's|Gemfile.lock||g' .gitignore
git add Gemfile.lock
git add .gitignore
git commit -m 'configs for heroku'
trap 'git reset HEAD~1 && rm config.yml && git checkout -- .gitignore' EXIT
git push heroku master -f

