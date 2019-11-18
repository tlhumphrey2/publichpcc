Admin Instance

Here are the instructions for setting up a small instance that can be used to start and stop your hpcc cluster. By doing this, you can reduce the AWS charges significantly. This instance will always be running. But, because it is small and only the root EBS volume is attached to it, the cost will be small.

1.  From the github repo, <https://github.com/tlhumphrey2/EasyFastHPCCoAWS>, put the contents of the StopStartHPCC folder in an s3 bucket (I call my bucket, s3://StopStartHPCC). ALSO PUT your private key file in the s3 bucket (the same one you use for the cluster).

2.  Using the Amazon AMI, launch a t2.micro instance in the same VPC as your hpcc cluster. Be sure to enable public address. Plus, using the same private key file as you’re using for your cluster.

3.  Ssh into bastion and configure the awscli with the following command:

```
aws configure
```

You will be asked to enter the following information (for Default output format just hit Return):

```
AWS Access Key ID:                            
AWS Secret Access Key:                           
Default region name:                
Default output format [None]:
```

4.  Use the following command to download from your StopStartHPCC s3 bucket all its contents:

| aws s3 cp s3://StopStartHPCC . --recursive |
|--------------------------------------------|

5.  Do the following. And, "your-private-key.pem" should be your private key file name.

```
chmod 755 *.pl                         
chmod 755 *.sh                          
chmod 400 your-private-key.pem
```

6.  Change ClusterInitVariables.pl like so (note: for readability, I have removed end of line comments). Place your information where I have "\<what you should enter\>":

```
$sshuser=”ec2-user”;                                                     
#$no_hpcc=1;                                                            
#$EBSVolumesMountedByFstab=1;                                            
#$asgfile=”asgnames.txt”;                                                
#$ephemeral=1;                                                           
$region=”<your region>”;                                            
$stackname=”<your stack name>”;                                     
$name=($stackname !~ /^\s*$/)? $stackname : “No Name”;  
$master_name=”$name—Master”;                                             
$other_name=”$name—Slave,$name—Roxie”;                                   
$pem=”<the name of your private key file>";                         
$private_ips_file=”private_ips.txt”;                                   
$instance_id_file=”instance_ids.txt”;                                  
$mountpoint=($no_hpcc)? “/home/$sshuser/data” : “/var/lib/HPCCSystems”;
```

7.  Once ClusterInitVariables.pl has been modified, run the following command to put a list of private IPs and instance ids in private_ips.txt and instance\_ids.txt, respectively:

| ./getPrivateIPs-InstanceIDs.pl |
|---------------------------------|

8.  Suspend scaling group functions – so new instances are NOT automatically created when stopping the cluster:

| ./suspendASGProcesses.pl |
|---------------------------|

***So, the above is the end of the setup. ***

To stop the cluster and all its instances do the following:

| ./stopAllInstances.pl &\> stop.log |
|------------------------------------|

To start the cluster and all its instances do the following:

| ./startAllInstances.pl &\> start.log |
|--------------------------------------|

Note. It isn’t necessary to pipe stderr and stdout to a log fle (like the above 2 commands). But if you have problems, it will help your isolate the problem.

