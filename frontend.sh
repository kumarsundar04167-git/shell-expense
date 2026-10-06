#!/bin/bash
userid=$(id -u)
LOGS_FOLDER=var/log/expense
sudo mkdir -p $LOGS_FOLDER
sudo chown -R ec2-user:ec2-user var/log/expense
sudo chmod -R 755 var/log/expense
LOGS_FILE=$LOGS_FOLDER/$0.logs
SCRIPT_DIR=$PWD

TIMESTAMP=$(date +%H:%M:%S)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

MYSQL_HOST=mysql.devopsonline.online


if [ $userid -ne 0 ]; then
   echo -e " $TIMESTAMP $R please run this script as a root user $N" | tee -a $LOGS_FILE
   exit 1
fi

validate(){
    if [ $1 -ne 0 ]; then
       echo -e " $TIMESTAMP $R [ERROR] $N task of $2 is ....... $R failed $N "  | tee -a $LOGS_FILE
       exit 1
    else
       echo -e " $TIMESTAMP $Y [INFO] $N task of $2 is ....... $G success $N "   | tee -a $LOGS_FILE
    fi
}

dnf list installed nginx  &>>$LOGS_FILE
if [ $? eq 0 ]; then
   echo -0e "$TIMESTAMP $Y [INFO] $N already installed ...... $Y skipping $N " | tee -a $LOGS_FILE
else
   echo -e "$TIMESTAMP $Y installing nginx $N " | tee -a $LOGS_FILE
   dnf install nginx -y &>>$LOGS_FILE
   validate $? "installing nginx"
fi

systemctl enable nginx  &>>$LOGS_FILE
systemctl start nginx  &>>$LOGS_FILE
validate $? "enable and start the nginx"

rm -rf /usr/share/nginx/html/*  &>>$LOGS_FILE
validate $? "removing default nginx content"

curl -o /tmp/frontend.tar.gz https://raw.githubusercontent.com/daws-90s/expense-documentation/refs/heads/main/artifacts/expense-frontend-v3.tar.gz  &>>$LOGS_FILE
validate $? "downloading the code"

cd /usr/share/nginx/html  &>>$LOGS_FILE
tar -xzf /tmp/frontend.tar.gz --strip-components=1  &>>$LOGS_FILE
validate $? "extracting the code directly into the web root"

cp $SCRIPT_DIR/expense.conf /etc/nginx/default.d/expense.conf  &>>$LOGS_FILE
validate $? "copying the file to directory"

systemctl restart nginx
validate $? "restartingthe nginx"
