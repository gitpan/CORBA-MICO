#!/bin/sh

hostname=`hostname`
dbfile=/tmp/ird

rm -f $HOME/.micorc
#echo "-ORBDebugLevel 10" > $HOME/.micorc

killall ird

echo "Giving ird a little time to die..."
sleep 1;

IDLS="Account.idl"

rm -f $dbfile.idl

ird -ORBIIOPAddr inet:$hostname:8888 --db $dbfile &

echo "Giving ird a little time to start..."
sleep 1;
echo "-ORBIfaceRepoAddr inet:$hostname:8888" >> $HOME/.micorc

for i in $IDLS ; do
   idl --no-codegen-c++ --feed-ir $i
done
