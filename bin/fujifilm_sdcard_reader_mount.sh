echo "RUN THE FOLLOWING COMMAND YOURSELF IF YOU HAVEN'T ALREADY"
echo sudo apt-get install exfat-fuse exfat-utils
#sudo apt-get install exfat-fuse exfat-utils

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
echo "Find last USB device in dmesg output above, replace 'sdb1' in the mount command below"

echo
echo
echo 'MODIFY & RUN THE FOLLOWING COMMAND YOURSELF'
echo sudo mount -t exfat /dev/sdb1 /mnt/fujifilm_xp
#sudo mount -t exfat /dev/sdb1 /mnt/fujifilm_xp

echo
echo
echo 'RUN THE FOLLOWING COMMAND YOURSELF'
echo sudo ls /mnt/fujifilm_xp/
#sudo ls /mnt/fujifilm_xp/

