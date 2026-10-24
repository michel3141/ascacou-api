#!/bin/bash
cd "$(git rev-parse --show-toplevel)" || exit 1

cat << ERD > .erdconfig
# https://voormedia.github.io/rails-erd/customise.html
attributes:
  - content
  - foreign_keys
  - inheritance
disconnected: true
filename: public/erd
generator: graphviz
filetype: png
indirect: true
inheritance: false
markup: true
notation: simple
orientation: vertical
polymorphism: false
sort: true
warn: true
title: true
exclude:
  - /^ActiveRecord::/
  - /^SolidQueue::/
  - /^SolidCable::/
  - /^SolidCache::/
#  - ActiveRecord::SchemaMigration
#  - ActiveRecord::InternalMetadata
#  - SolidCache::Entry
#  - SolidQueue::Semaphore
#  - SolidQueue::RecurringTask
#  - SolidQueue::Process
#  - SolidQueue::Pause
#  - SolidQueue::Job
#  - SolidQueue::ScheduledExecution
#  - SolidQueue::RecurringExecution
#  - SolidQueue::ReadyExecution
#  - SolidQueue::FailedExecution
#  - SolidQueue::ClaimedExecution
#  - SolidQueue::BlockedExecution
#  - SolidCable::Message
#  - SolidQueue::Job
only: null
#only:
#  - User
#  - Account
#  - Subscription
#  - Invoice
only_recursion_depth: null
prepend_primary: false
cluster: false
#splines: spline
splines: ortho
fonts:
 normal: "Arial"
 bold: "Arial Bold"
 italic: "Arial Italic"
ERD
bundle add --group development rails-erd
bundle add --group development ruby-graphviz
rails generate erd:install
rails db:migrate
