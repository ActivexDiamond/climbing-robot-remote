#!/bin/bash
#Pulls the latest version of the repo for both the remote and robot.
sudo git reset --hard HEAD
sudo git pull
cp -rf py/TensorFlow.py ~/or/models/research/object_detection/TensorFlow.py