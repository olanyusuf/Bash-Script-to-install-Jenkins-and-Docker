#!/bin/bash

echo -n "please enter the password:"
read password
echo "new password is: $password"  


echo -n "please enter the mount device:"
read mountDev
echo "input mount device is: $mountDev"


current="`pwd`"
mountPath=$current/mountDir
volTemp="volTemp"
ret=255

function return_assert(){  
    if [ $1 -ne 0 ];then
        echo "return_assert: line $2 error, return $1, cmd: $3"
        exit 1
    fi
}

function write_rc_file(){

    rc_rc=${mountPath}/etc/rc.d/rc
	rc_local=${mountPath}/etc/rc.d/rc.local
    init_rc=${mountPath}/etc/init.d/rc
	boot_local=${mountPath}/etc/init.d/boot.local
    addline="/bin/bash /etc/init.d/setpasswd.sh"

    if [ -f $rc_rc ];then
        grep -n "^exit 0" $rc_rc
        if [ $? -eq 0 ];then
            line_num=`grep -n "^exit 0" ${rc_rc} | awk -F'[:]' '{print $1}'`
            sed -i "${line_num} i${addline}" ${rc_rc} #add line before "exit 0"
        else
            echo $addline >> $rc_rc    
        fi
		chmod +x $rc_rc
	fi
	
	if [ -f $rc_local ];then
        grep -n "^exit 0" $rc_local
        if [ $? -eq 0 ];then
            line_num=`grep -n "^exit 0" ${rc_local} | awk -F'[:]' '{print $1}'`
            sed -i "${line_num} i${addline}" ${rc_local} #add line before "exit 0"
        else
            echo $addline >> $rc_local    
        fi
		chmod +x $rc_local
	fi
	
	if [ -f $init_rc ];then    
        grep -n "^exit 0" $init_rc
        if [ $? -eq 0 ];then
            line_num=`grep -n "^exit 0" ${init_rc} | awk -F'[:]' '{print $1}'`
            sed -i "${line_num} i${addline}" ${init_rc} #add line before "exit 0"
        else
            echo $addline >> $init_rc    
        fi
		chmod +x $init_rc
    fi
	
	if [ -f $boot_local ];then    
        grep -n "^exit 0" $boot_local
        if [ $? -eq 0 ];then
            line_num=`grep -n "^exit 0" ${boot_local} | awk -F'[:]' '{print $1}'`
            sed -i "${line_num} i${addline}" ${boot_local} #add line before "exit 0"
        else
            echo $addline >> $boot_local    
        fi
		chmod +x $boot_local
    fi
	
    echo "write to rc success."
}

function write_windows_scripts(){

    script=${mountPath}/Windows/System32/GroupPolicy/Machine/Scripts/scripts.ini
    script_dir=${mountPath}/Windows/System32/GroupPolicy/Machine/Scripts
    if [ -f $script ];then
        sed -i '/^$/d' $script  #strip space lines
        cat $script | grep -iq '\[Startup\]'
        if [ $? -eq 0 ];then
            startup_num=`grep -n "\[Startup\]" $script | cut -d ":" -f 1`
            cat $script | grep -iq '\[Shutdown\]'
            if [ $? -eq 0 ];then
                shutdown_num=`grep -n "\[Shutdown\]" $script | cut -d ":" -f 1`
                if [ "$startup_num" -gt "$shutdown_num" ];then
                    lastline="`tail -n1 $script`"
                    cmdline_num=`echo $lastline | grep -oE "^[0-9]+"`
                    new_cmdline_num="`expr $cmdline_num + 1`"
                    echo -ne "${new_cmdline_num}CmdLine=setpasswd.vbs\\r\\n" >> $script
                    echo -ne "${new_cmdline_num}Parameters=\\r\\n" >> $script
                else
                    startup_lastline_num="`expr $shutdown_num - 1`"
                    startup_lastline=`sed -n ${startup_lastline_num}p $script`
                    cmdline_num=`echo $startup_lastline | grep -oE "^[0-9]+"`
                    new_cmdline_num="`expr $cmdline_num + 1`"
                    parameters="${new_cmdline_num}Parameters=\\r\\n"
                    cmdline="${new_cmdline_num}CmdLine=setpasswd.vbs\\r\\n"
                    sed -i "/\[Shutdown\]/i${cmdline}" $script #insert cmdline before [Shutdown] group
                    sed -i "/\[Shutdown\]/i${parameters}" $script
                fi
            else
                lastline="`tail -n1 $script`"
                cmdline_num=`echo $lastline | grep -oE "^[0-9]+"`
                new_cmdline_num="`expr $cmdline_num + 1`"
                echo -ne "${new_cmdline_num}CmdLine=setpasswd.vbs\\r\\n" >> $script
                echo -ne "${new_cmdline_num}Parameters=\\r\\n" >> $script
            fi
        else
            echo -ne "[Startup]\\r\\n" >> $script
            echo -ne "0CmdLine=setpasswd.vbs\\r\\n" >> $script
            echo -ne "0Parameters=\\r\\n" >> $script
        fi
    else
        mkdir -p $script_dir
        echo -ne "[Startup]\\r\\n" >> $script
        echo -ne "0CmdLine=setpasswd.vbs\\r\\n" >> $script
        echo -ne "0Parameters=\\r\\n" >> $script
    fi

    echo "write to scripts.ini success."
}

function create_setpasswd_sh(){

    filename=${mountPath}/etc/init.d/setpasswd.sh
    if [ -f $filename ];then
        rm $filename
    fi
    echo "#!/bin/bash" >> $filename
    echo "echo \"root:${password}\" | chpasswd" >> $filename
    echo "rm -f /etc/init.d/setpasswd.sh" >> $filename
    chmod +x $filename
    echo "create setpasswd.sh success."
}

function create_setpasswd_vbs(){

    filename=${mountPath}/Windows/System32/GroupPolicy/Machine/Scripts/Startup/setpasswd.vbs
    file_dir=${mountPath}/Windows/System32/GroupPolicy/Machine/Scripts/Startup
    if [ -f $filename ];then
        rm $filename
    fi
    mkdir -p $file_dir
    echo -ne "Set objUser = GetObject(\"WinNT://./Administrator,user\")\\r\\n" >> $filename
    echo -ne "objUser.SetPassword \"${password}\"\\r\\n" >> $filename
    echo -ne "objUser.SetInfo\\r\\n" >> $filename
    echo -ne "strPath = Wscript.ScriptFullName\\r\\n" >> $filename
    echo -ne "Set objFSO = CreateObject(\"Scripting.FileSystemObject\")\\r\\n" >> $filename
    echo -ne "Set objFile = objFSO.GetFile(strPath)\\r\\n" >> $filename
    echo -ne "f = objFSO.DeleteFile(objFile)\\r\\n" >> $filename

    echo "create setpasswd.vbs success."
}

function mount_dev(){

    if [ -d "${mountPath}/Windows/System32" ];then
        write_windows_scripts
        create_setpasswd_vbs
        return 0
    elif [ -d "${mountPath}/etc/init.d" ];then
        write_rc_file
        create_setpasswd_sh
        return 0
    fi

    return 1
}

echo "begin setpassword ..."

if [ ! -d "$mountPath" ];then
    mkdir -p $mountPath
fi

devs=`fdisk -l | grep "^$mountDev" | awk '{print $1}'`
for dev in $devs;do
    echo "trying device : ${dev} ..."
    dev_type=`fdisk -l | grep "^$dev" | grep -i "lvm"`
    if [ $? -eq 0 ];then
        lvmFlag="lvmType"
    else
        lvmFlag="normal"
    fi

    if [ "$lvmFlag" == "normal" ];then
        mount $dev $mountPath
        mount_dev
        ret=$?
        umount $mountPath
        if [ $ret -eq 0 ];then
            rmdir $mountPath
            echo "set password success."
            exit 0
        fi
    elif [ "$lvmFlag" == "lvmType" ];then
        vgchange -ay
        sleep 1
        vg="`pvs $dev | grep $dev | awk '{print $2}'`"
        lvs="`lvs $vg | grep -v 'LSize' | awk '{print $1}'`"
        for lv in $lvs;do
            tableValues="`dmsetup table ${vg}-${lv}`"
            if [ $? -ne 0 ];then #ubuntu's VG name is different
                vg_alias="`echo $vg | sed 's/-/--/g'`"
                tableValues="`dmsetup table ${vg_alias}-${lv}`"
            fi
            sectors="`echo ${tableValues} | awk '{print $2}'`"
            startSector="`echo ${tableValues} | awk '{print $5}'`"
            targetDev_first="`ls -l $dev | awk -F'[,]' '{print $1}' | awk '{print $5}'`"
            targetDev_second="`ls -l $dev | awk -F'[,]' '{print $2}' | awk '{print $1}'`"
            echo -e "0 $sectors linear ${targetDev_first}:${targetDev_second} $startSector" | dmsetup create $volTemp
            mount /dev/mapper/$volTemp $mountPath
            mount_dev
            ret=$?
            umount $mountPath
            dmsetup remove $volTemp
            if [ $ret -eq 0 ];then
                rmdir $mountPath
                echo "set password success."
                exit 0
            fi
        done
    fi
done

echo "set password failed."
exit 1
