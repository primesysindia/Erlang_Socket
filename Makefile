PROJECT = chat

DEPS = bullet mongodb jsx
dep_mongodb = git git://github.com/mongodb/mongodb-erlang.git master
dep_jsx = git https://github.com/talentdeficit/jsx.git master

include erlang.mk
