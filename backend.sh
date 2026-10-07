#!/bin/bash
userid=$(id -u)
LOGS_FOLDER="/var/log/expense"
sudo mkdir -p "$LOGS_FOLDER"
sudo chown -R ec2-user:ec2-user /var/log/expense
sudo chmod -R 755 /var/log/expense
SCRIPT_NAME=$(basename "$0")
LOGS_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR=$PWD

TIMESTAMP=$(date +%H:%M:%S)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

MYSQL_HOST=mysql.devopsonline.online


if [ $userid -ne 0 ]; then
   echo -e " $TIMESTAMP $R please run this script as a root user $N"
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

dnf module disable nodejs -y
dnf module enable nodejs:20 -y
validate $? "disabled and then enabled nodejs 20"

dnf install nodejs -y
validate $? "installing nodejs"

mkdir -p /app
validate $? "creating app directory"

id expense
if [ $? -eq 0 ]; then
   echo -e " $TIMESTAMP $Y [INFO] $N alreary created expense user ...... $Y skipping $N " | tee -a $LOGS_FILE
   exit 1
else
   echo "creating expense user" | tee -a $LOGS_FILE
   useradd --system --home /app --shell /sbin/nologin --comment "expense system user" expense  &>>$LOGS_FILE
   validate $? "creating system user"
fi

curl -o /tmp/backend.tar.gz https://raw.githubusercontent.com/daws-90s/expense-documentation/refs/heads/main/artifacts/expense-backend-v3.tar.gz  &>>$LOGS_FILE
validate $? "downloding the code into /tmp/backend.tar.gz"

cd /app
tar -xzf /tmp/backend.tar.gz --strip-components=1 &>>$LOGS_FILE
validate $? "extracting the code into app directory"

cd /app
npm install &>>$LOGS_FILE
validate $? "installing the dependencies"

cp $SCRIPT_DIR/backend.service /etc/systemd/system/backend.service &>>$LOGS_FILE
validate $? "copying backend.service file to/etc/systemd/system/backend.service "

dnf list installed mysql  &>>$LOGS_FILE
if [ $? -eq 0 ]; then
   echo -e " $TIMESTAMP $Y [INFO] $N installing mysql-server already installed ........ $Y skipping $N " | tee -a $LOGS_FILE
else
   echo "installing mysql-server" | tee -a $LOGS_FILE
   dnf install mysql -y &>>$LOGS_FILE
   validate $? "installing mysql-server"
fi
mysql -h $MYSQL_HOST -u root -pExpenseApp@1 < /app/schema/backend.sql &>>$LOGS_FILE
validate $? "loading the schema"

systemctl daemon-reload  &>>$LOGS_FILE
validate $? "daemon reloading"

systemctl enable backend  &>>$LOGS_FILE
systemctl start backend   &>>$LOGS_FILE
validate $? "enable and start the backend"