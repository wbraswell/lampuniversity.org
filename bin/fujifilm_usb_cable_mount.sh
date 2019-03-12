echo "RUN THE FOLLOWING COMMAND YOURSELF IF YOU HAVEN'T ALREADY"
echo sudo apt-get install gphoto2 gphotofs
#sudo apt-get install gphoto2 gphotofs

echo
echo
echo 'NOW RUNNING THE FOLLOWING COMMAND'
echo sudo umount /mnt/fujifilm_xp
sudo umount /mnt/fujifilm_xp

echo
echo
echo 'NOW RUNNING THE FOLLOWING COMMAND'
echo dmesg
dmesg

echo
echo
echo 'NOW RUNNING THE FOLLOWING COMMAND'
echo gphoto2 --list-ports
gphoto2 --list-ports

echo
echo
echo "Find matching USB device in dmesg & gphoto2 output above, replace '002,008' in the gphotofs command below"

echo
echo
echo 'MODIFY & RUN THE FOLLOWING COMMAND YOURSELF'
echo sudo gphotofs --port=usb:002,008 /mnt/fujifilm_xp/
#sudo gphotofs --port=usb:002,008 /mnt/fujifilm_xp/

echo
echo
echo 'RUN THE FOLLOWING COMMAND YOURSELF'
echo sudo ls /mnt/fujifilm_xp/
#sudo ls /mnt/fujifilm_xp/

