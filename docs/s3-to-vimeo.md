* Create an instance (default amazon linux ami)
* ssh -i ~/.ssh/aws-chris-imac.pem  ec2-user@ip-address
* sudo yum update
* sudo yum install ftp
* aws configure
* aws s3 ls s3://talk.objc.io/originals > files.txt
* use vim to delete the non-filename parts in files.txt
* sort -n files.txt > sorted.txt
* make sure to remove all the files that are already uploaded.
* bash script:
#!/bin/bash
set -euxo pipefail

while read f; do
        aws s3 cp "s3://talk.objc.io/originals/$f" .
        curl -T "$f" ftp://ftp-3.cloud.vimeo.com --user user90241434:y2r-o2g-5im-r3p
        rm "$f"
done <sorted.txt
~                    
