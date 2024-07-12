# scripts-telecomm-latency/scripts/gathering
Script to gather latency data.

Created for Ubuntu 22.04 (jammy jellyfish)

The script takes 2 parameters:
  file number or "next"
  the latency (delay) amount in microseconds

The second parameter defaults to random if omitted. Thus, after testing was complete, I always ran the script this way: "python latency.py next".

Hardware: two sound cards, each with a microphone and headphones connected. 

