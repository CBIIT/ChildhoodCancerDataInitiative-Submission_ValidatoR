import subprocess
import argparse
import argcomplete
from datetime import date
import os


parser = argparse.ArgumentParser(
                    prog='Bucket_ls.py',
                    description='A script to create a ls --recursive list of bucket for ingest into the validation scripts. This is used when the pipeline needs to be run on a machine (VM) that does not have aws access, and this output is then transfered to that machine.',
                    )

parser.add_argument( '-s', '--s3_bucket', help="The s3 bucket location, in the format of 's3://bucket/name/here/'")
parser.add_argument( '-o', '--output', help="The directory location of the output file. The default is the current directory.",default="./")

argcomplete.autocomplete(parser)

args = parser.parse_args()

#obtain the date
def refresh_date():
    today=date.today()
    today=today.strftime("%Y%m%d")
    return today

#pull in args as variables
s3_bucket=args.s3_bucket
output=args.output
output=os.path.abspath(output)


#Test bucket to make sure expected parts are there.
if s3_bucket.find("s3://") != 0:
    s3_bucket="s3://"+s3_bucket

if s3_bucket[len(s3_bucket)-1]!="/":
    s3_bucket=s3_bucket+"/"

#Make sure dir location is setup correctly
if output[len(output)-1]!="/":
    output=output+"/"

date=refresh_date()

#Pull file from AWS CLI
subprocess.run([f"aws s3 ls --recursive {s3_bucket} > bucket.txt"], shell=True)

#Read in file
bucket_file=open("bucket.txt", "r")

bucket_files=bucket_file.read()

#Clean up file
while bucket_files.find('  ') != -1:
    bucket_files=bucket_files.replace('  ', ' ')

bucket_files=bucket_files.replace(' ','\t')

#Clean up file name
bucket_name=s3_bucket.split("s3://")[1]
bucket_name=bucket_name.replace("/","_")
bucket_name=bucket_name[:-1]

#Remove s3 output file
subprocess.run(["rm bucket.txt"], shell=True)

#Write out TSV for input into script.
tsv_text= open(f"{output}{bucket_name}_{date}.tsv","w")
n=tsv_text.write(bucket_files)
tsv_text.close()
