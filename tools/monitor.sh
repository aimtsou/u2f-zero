#!/bin/bash


export PATH=$PATH:`pwd`/flashing:../../../u2f_zero_client:../../../gencert

export key=gencert/ca/key.pem
adapters[0]=0
num_adapters=0
firmware=../firmware
export setup=setup_device.sh
export starting_SN=CAFEBABE00000000
setup_SNs=(0 CAFEBABEFFFFFFF0 CAFEBABEFFFFFFF1 CAFEBABEFFFFFFF2)

function inc_hex {
    a=$((0x$1 + 1))
    a=$(printf "%x\n" $a)
    echo ${a^^}
}

function is_running {

    sn=$1
    if [[ -f workers/$sn/worker/.finished ]] ; then
        pwd
        echo "$sn finished"
        return 1
    fi
    
    pwd
    echo "$sn still running"
    return 0

}

function start_programming {

    sn=$1
    setupf=$2
    setup_sn=$3
    rm -f workers/$sn/worker/.finished
    cd workers/$sn/worker && ./$setup ../../../$key $sn $starting_SN $setupf $setup_sn \
        && touch .finished && cd ../../.. &
    export starting_SN=$(inc_hex $starting_SN)

}


for i in `seq 1 100` ; do

    adapters[$i]=$(FlashUtilCL.exe DeviceSN $i)

    if [[ ${adapters[$i]} = *"out of range"* ]]
    then
        break
    fi

    num_adapters=$(($num_adapters + 1))
done

export num_adapters=$num_adapters
export adapters=$adapters

rm -rf workers
mkdir workers

for i in `seq 1 $num_adapters` ; do

    echo "$i :" ${adapters[$i]}
    mkdir workers/${adapters[$i]}
    mkdir workers/${adapters[$i]}/worker
    cp -rf $firmware workers/${adapters[$i]}
    cp  $setup workers/${adapters[$i]}/worker
    touch workers/${adapters[$i]}/worker/.finished

    # fix path in meta file to point to new location for files that are "dynamic"
    sed -i "s/firmware.*src.*cert.c/tools\/workers\/${adapters[$i]}\/firmware\/src\/cert.c/g"  \
        workers/${adapters[$i]}/firmware/release/src/cert.__i 
    sed -i "s/firmware.*src.*descriptors.c/tools\/workers\/${adapters[$i]}\/firmware\/src\/descriptors.c/g"  \
        workers/${adapters[$i]}/firmware/release/src/descriptors.__i

done

#cd workers/${adapters[1]}/worker && ./$setup ../../../$key ${adapters[1]} CAFEBABE00000001

starting_SN=$(inc_hex $starting_SN)
echo $starting_SN

#cd workers/${adapters[1]}/worker && ./$setup ../../../$key ${adapters[1]} CAFEBABE00000001 &
#is_running ${adapters[1]}
#echo $?

#exit 0

for (( ; ; ))
do

    read -n 1 j

    if [[ $j -gt $num_adapters ]] ; then

        echo "$j is too big"
        continue

    fi

    is_running ${adapters[$j]}

    if [[ $? -eq 1 ]] ; then
        echo "starting $j ${adapters[$j]}"
        start_programming ${adapters[$j]} ../firmware/SETUP_"${setup_SNs[$j]}".hex ${setup_SNs[$j]}
    else
        echo "$j ${adapters[$j]} is already running"
    fi

done

