#!/bin/bash

# configure IP addresses
p4app exec m h1 ip addr add 10.0.10.1/24 dev h1-eth0
p4app exec m h2 ip addr add 10.0.10.2/24 dev h2-eth0

# run ping
sleep 2
p4app exec m h1 ping -c 10 10.0.10.2 
