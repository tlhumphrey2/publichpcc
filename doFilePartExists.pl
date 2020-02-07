#!//usr/bin/perl
$subdir=shift @ARGV;
$FilePartsExists='file parts  do not exist';
if ( -e "/var/lib/HPCCSystems/hpcc-data/$subdir" ){ 
  $_=`sudo ls -lR /var/lib/HPCCSystems/hpcc-data/$subdir 2>&1`;
  $FilePartsExists='file parts exist' if /\._\d+_of_\d+/s;
}
print($FilePartsExists);
