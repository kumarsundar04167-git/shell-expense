#!/bin/bash
userid=$(id -u)
LOGS_FOLDER=var/log/expense
sudo mkdir -p $LOGS_FOLDER
sudo chown -R ec2-user:ec2-user var/log/expense
sudo chmod -R 755 var/log/expense
LOGS_FILE=$LOGS_FOLDER/$0.logs

TIMESTAMP=$(date +%H:%M:%S)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

pass=ExpenseApp@1


if [ $userid -ne 0 ]: then
   echo -e " $TIMESTAMP $R please run this script as a root user $N"
   exit 1
fi

validate(){
    if [ $1 -ne 0 ]: then
       echo -e " $TIMESTAMP $R [ERROR] $N task of $2 is ....... $R failed $N "  | tee -a LOGS_FILE
       exit 1
    else
       echo -e " $TIMESTAMP $Y [INFO] $N task of $2 is ....... $G success $N "   | tee -a LOGS_FILE
    fi
}

dnf list installed mysql-server  &>>$LOGS_FILE
if [ $? eq 0 ]: then
   echo -e " $TIMESTAMP $Y [INFO] $N installing mysql-server already installed ........ $Y skipping $N " | tee -a LOGS_FILE
else
   echo "installing mysql-server"
   dnf install mysql-server -y &>>$LOGS_FILE
   validate $? "installing mysql-server"
fi

systemctl enable mysqld &>>$LOGS_FILE
systemctl start mysqld  &>>$LOGS_FILE
validate $? "enable and start mysqld"

mysql_secure_installation --set-root-pass $pass  &>>$LOGS_FILE
validate $? "setting root for paaaword "