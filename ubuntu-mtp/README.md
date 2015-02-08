# Description

This script configures Unbuntu 12.04 to auto-mount/unmount Android internal storage that's served through MTP. 
This script only needs to run successfully once with a *particular* Android device, and that device will be able 
to continually auto-mount/unmount when plugged/unplugged (even after reboot).  

# Background

MTP stands for multimedia transfer protocol, and it has been the standard way to access the phone's internal 
storage via a computer since Android 4.4.2. With the old USB mass storage mounting gone since Android 4.4.2, 
un-rooted Android phones are forced to utilize MTP in order to expose its internal storage to a computer. 

Ubuntu 12.04 is an old operating system relative to this change and doesn't support MTP in a very meaningful way, 
which means many vanilla Android 4.4.2+ phones fail to mount on Ubuntu 12.04. This script installs un-supported 
binaries from later versions of Ubuntu to make mounting happen successfully via MTP.  

# Requirements

* Ubuntu 12.04 (I don't know what, if anything, may happen if you try this on a newer version of Ubuntu)  
* Android devices should be set to use MTP (the alternative protocol would be PTP)  

# Features

* Script supports re-running multiple times for a particular device  
* Do a one-time setup to install the necessary packages and configure some prerequisites (`-i` flag)  
  * This can be done with no device connected  
* Query information only or also set up auto-mounting/unmounting for a device (`-f` flag)  
  * This should be done with at least one device connected; otherwise it's not very interesting  
  * This is done on a per-device level with prompts to skip certain devices or steps  
* Set up multiple connected devices automatically (`-y` flag)  

# Credit

Steps were taken from this guide: http://bernaerts.dyndns.org/linux/74-ubuntu/268-ubuntu-automount-any-mtp-device
