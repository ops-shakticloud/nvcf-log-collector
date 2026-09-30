#!/bin/bash
#37061dfa-f0e8-4fe3-9e27-a4048ef5a394,nvcf-backend,0-sr-0d81b115-e187-45b2-b2be-57cedba0513f,nvcf-h100-008

export _DATE1="$(date +'%b %d' -d '1 day ago')"
export _DATE2="$(date +'%b %d')"
export _TOP=$PWD
cd $_TOP

echo "INFO: setting up data under($_TOP)"



function collect_pod_container_logs () {

    _FUNCTION_ID=$1
    if [[  -z "${_FUNCTION_ID// }"  ]]
    then
	    echo "ERROR:function id is blank($_FUNCTION_ID)" > error.log
	    return
    fi


    echo "INFO: pod list for $_FUNCTION_ID"
    echo "kubectl get pods -A  -l FUNCTION_ID=$_FUNCTION_ID" > fid_pod.csv.cmd
    kubectl get pods -A  -l FUNCTION_ID="$_FUNCTION_ID"   -o jsonpath='{range .items[*]}{.metadata.labels.FUNCTION_ID},{.metadata.namespace},{.metadata.name},{.spec.nodeName},{.metadata.creationTimestamp}{"\n"}{end}' > fid_pod.csv



    for _LINE in $(cat fid_pod.csv)
    do
        _FID=$(echo $_LINE|cut -d, -f1)
        _NS=$(echo $_LINE|cut -d, -f2)
        _POD=$(echo $_LINE|cut -d, -f3)    

	_FILE="k_d_p_ns.${_NS}_pod.$_POD.out"
        echo "kubectl describe pod  -n $_NS $_POD" > ${_FILE}.cmd
	echo "kubectl describe pod  -n $_NS $_POD" > ${_FILE}
        kubectl describe pod  -n $_NS $_POD >> ${_FILE} 2>&1 


        for _CONT in $(kubectl get pod $_POD -n $_NS -o jsonpath='{.spec.containers[*].name}')
        do
	   
            _FILE="fid.${_FID}_ns.${_NS}_pod.${_POD}_cont.${_CONT}.out"
            echo "INFO: $_FILE"
	    echo "kubectl logs -n "$_NS" "$_POD" -c "$_CONT" --timestamps" >  ${_FILE}.cmd
            echo "kubectl logs -n "$_NS" "$_POD" -c "$_CONT" --timestamps" >  ${_FILE}
            echo "kubectl logs -n "$_NS" "$_POD" -c "$_CONT" --timestamps" >>  ${_FILE}

	    kubectl logs -n "$_NS" "$_POD" -c "$_CONT" --timestamps  >> ${_FILE} 2>&1
            
        done


	
        echo "INFO: getting image pull secrets for $_FILE"
        _FILE=fid.${_FID}_ns.${_NS}_pod.${_POD}_imagePullSecrets.out
        echo "kubectl get pod -n $_NS $_POD -o jsonpath='{.spec.imagePullSecrets[*].name}'" > ${_FILE}.cmd 2>&1
        echo "kubectl get pod -n $_NS $_POD -o jsonpath='{.spec.imagePullSecrets[*].name}'" > ${_FILE} 2>&1
        _SECRETS=$(kubectl get pod -n "$_NS" "$_POD" -o jsonpath='{.spec.imagePullSecrets[*].name}' 2>&1)
        echo "$_SECRETS" >> ${_FILE}


        # 2. metadata (NOT decoded contents) for each referenced secret
        for _SECRET in $_SECRETS
        do
	    
            _FILE=fid.${_FID}_ns.${_NS}_pod.${_POD}_secretmeta.${_SECRET}.out
	    echo "INFO: decoding and dumping secret in $_FILE"
            echo "kubectl get secret -n $_NS $_SECRET -o custom-columns=NAME:.metadata.name,TYPE:.type,CREATED:.metadata.creationTimestamp" > ${_FILE}.cmd 2>&1
            echo "kubectl get secret -n $_NS $_SECRET -o custom-columns=NAME:.metadata.name,TYPE:.type,CREATED:.metadata.creationTimestamp" > ${_FILE} 2>&1
            kubectl get secret -n "$_NS" "$_SECRET" -o custom-columns=NAME:.metadata.name,TYPE:.type,CREATED:.metadata.creationTimestamp  >> ${_FILE} 2>&1
	    kubectl get secret -n "$_NS" "$_SECRET" -o json |  jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"' >> ${_FILE} 2>&1
	    grep -oE '"auth":"[^"]*"' ${_FILE} | cut -d'"' -f4 |base64 -d >> ${_FILE} 2>&1
        done


    done


}


function collect_containerd_logs () {
    echo "INFO: collect_containerd_logs"

    for _NODE in ${_NODELIST[@]}
    do
	    mkdir $_NODE
	    echo "CMD: journalctl -u containerd --no-pager" >$_NODE/containerd.journalctl
	    ssh  $_NODE "journalctl -u containerd --no-pager"|grep -E -e "^${_DATE1}" -e "^${_DATE2}" >> $_NODE/containerd.journalctl &
    done

    wait
}



function collect_kubelet_logs () {
    echo "INFO: collect_kubelet_logs"

    for _NODE in ${_NODELIST[@]}
    do
	    mkdir $_NODE
	    echo "CMD: journalctl -u kubelet --no-pager" > $_NODE/kubelet.journalctl
	    ssh $_NODE "journalctl -u kubelet --no-pager" 2>&1|grep -E -e "^${_DATE1}" -e "^${_DATE2}"  >> $_NODE/kubelet.journalctl &
    done
    
    wait
}


function collect_crictl_logs () {
    echo "INFO: collect_crictl_logs"


    for _NODE in ${_NODELIST[@]}
    do
            mkdir $_NODE
            ssh $_NODE $_TOP/collect_crictl.sh $_TOP &
    done

    wait
}	



function collect_cluster_info () {
    # cluster/operator-level data
    mkdir -p cluster_info
    cd cluster_info


    _FILE=helm_list.txt
    echo "CMD: helm list -A ===" >${_FILE}.cmd
    echo "CMD: helm list -A ===" >${_FILE}
    helm list -A >> ${_FILE} 2>&1


    _FILE=helm_history_nvca_operator.txt
    echo "CMD: helm history nvca-operator ===" > ${_FILE}.cmd
    echo "CMD: helm history nvca-operator ===" > ${_FILE}
    helm history nvca-operator -n nvca-operator >> ${_FILE} 2>&1


    _FILE=nvcfbackend_all.yaml
    echo "CMD: kubectl get nvcfbackend -A -o yaml ===" > ${_FILE}.cmd
    echo "CMD: kubectl get nvcfbackend -A -o yaml ===" > ${_FILE}
    kubectl get nvcfbackend -A -o yaml >> nvcfbackend_all.yaml 2>&1


    _FILE=pods_nvca_operator.out
    echo "CMD: kubectl get pods -n nvca-operator -o wide nvca-operator pods ===" > ${_FILE}.cmd
    echo "CMD: kubectl get pods -n nvca-operator -o wide nvca-operator pods ===" > ${_FILE}
    kubectl get pods -n nvca-operator -o wide >> ${_FILE} 2>&1


    _FILE=pods_nvca_system.out
    echo "CMD: kubectl get pods -n nvca-system -o wide nvca-system pods ===" > ${_FILE}.cmd
    echo "CMD: kubectl get pods -n nvca-system -o wide nvca-system pods ===" > ${_FILE}
    kubectl get pods -n nvca-system -o wide >> ${_FILE} 2>&1


    _FILE=helm_get_values_ALL_RAW.out
    echo "CMD: helm get values --all ===" > ${_FILE}.cmd
    echo "CMD: helm get values --all ===" > ${_FILE}
    helm get values --all >> ${_FILE}


    for _RELEASE in $(helm list -A -o json | python3 -c "import json,sys; [print(r['name']+' '+r['namespace']) for r in json.load(sys.stdin)]")
    do
        _RNAME=$(echo $_RELEASE | awk '{print $1}')
        _RNS=$(echo $_RELEASE | awk '{print $2}')
	_FILE=helm_get_values_rname.${_RNAME}_rns.${_RNS}.out
        echo "CMD: helm get values $_RNAME -n $_RNS ===" > ${_FILE}.cmd
        echo "CMD: helm get values $_RNAME -n $_RNS ===" > ${_FILE}
        helm get values "$_RNAME" -n "$_RNS" --all >> ${_FILE} 2>&1
        echo "" >> ${_FILE}

    done


}


#nvca-operator                       nvca-operator-7c89d8cfc5-s9tcg                                    2/2     Running     0               12d
#nvca-system                         image-cred-updater-29846580-j57lj                                 0/1     Completed   0               8m25s
#nvca-system                         nvca-846fb9b658-dccr2                                             2/2     Running     0               12d

function collect_nvca_data {
    mkdir nvca_data
    cd nvca_data
    echo "kubectl get pods -A"|grep "nvca-" > nvca-pod.raw
    kubectl get pods -A  -o jsonpath='{range .items[*]}{.metadata.labels.FUNCTION_ID},{.metadata.namespace},{.metadata.name},{.spec.nodeName},{.metadata.creationTimestamp}{"\n"}{end}' |grep nvca > nvca-operator-pod.csv

    for _LINE in $(cat nvca-operator-pod.csv)
    do
        _NS=$(echo $_LINE|cut -d, -f2)
        _POD=$(echo $_LINE|cut -d, -f3)

        _FILE="k_d_p_ns.${_NS}_pod.$_POD.out"
        echo "kubectl describe pod  -n $_NS $_POD" > ${_FILE}.cmd
        echo "kubectl describe pod  -n $_NS $_POD" > ${_FILE}
        kubectl describe pod  -n $_NS $_POD >> ${_FILE} 2>&1


        for _CONT in $(kubectl get pod $_POD -n $_NS -o jsonpath='{.spec.containers[*].name}')
        do

            _FILE="fid.X.ns.${_NS}_pod.${_POD}_cont.${_CONT}.out"
            echo "INFO: $_FILE"
            echo "kubectl logs -n "$_NS" "$_POD" -c "$_CONT" --timestamps" >  ${_FILE}.cmd
            echo "kubectl logs -n "$_NS" "$_POD" -c "$_CONT" --timestamps" >  ${_FILE}
            echo "kubectl logs -n "$_NS" "$_POD" -c "$_CONT" --timestamps" >>  ${_FILE}

            kubectl logs -n "$_NS" "$_POD" -c "$_CONT" --timestamps  >> ${_FILE} 2>&1

        done



        echo "INFO: getting image pull secrets for POD  $_NS/$_POD"
        _FILE=fid.${_FID}_ns.${_NS}_pod.${_POD}_imagePullSecrets.out
        echo "kubectl get pod -n $_NS $_POD -o jsonpath='{.spec.imagePullSecrets[*].name}'" > ${_FILE}.cmd 2>&1
        echo "kubectl get pod -n $_NS $_POD -o jsonpath='{.spec.imagePullSecrets[*].name}'" > ${_FILE} 2>&1
        _SECRETS=$(kubectl get pod -n "$_NS" "$_POD" -o jsonpath='{.spec.imagePullSecrets[*].name}' 2>&1)
        echo "$_SECRETS" >> ${_FILE}


        # 2. metadata (NOT decoded contents) for each referenced secret
        for _SECRET in $_SECRETS
        do

            _FILE=fid.${_FID}_ns.${_NS}_pod.${_POD}_secretmeta.${_SECRET}.out
            echo "INFO: decoding and dumping secret in $_FILE"
            echo "kubectl get secret -n $_NS $_SECRET -o custom-columns=NAME:.metadata.name,TYPE:.type,CREATED:.metadata.creationTimestamp" > ${_FILE}.cmd 2>&1
            echo "kubectl get secret -n $_NS $_SECRET -o custom-columns=NAME:.metadata.name,TYPE:.type,CREATED:.metadata.creationTimestamp" > ${_FILE} 2>&1
            kubectl get secret -n "$_NS" "$_SECRET" -o custom-columns=NAME:.metadata.name,TYPE:.type,CREATED:.metadata.creationTimestamp  >> ${_FILE} 2>&1
	    kubectl get secret -n "$_NS" "$_SECRET" -o json |  jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"' >> ${_FILE} 2>&1
        done


    done
    

}

function collect_kube_system_data {
    mkdir kube_system_data
    cd kube_system_data
    echo "kubectl get pods -A"|grep "kube-system" > kube-system-pod.raw
    kubectl get pods -A  -o jsonpath='{range .items[*]}{.metadata.labels.FUNCTION_ID},{.metadata.namespace},{.metadata.name},{.spec.nodeName},{.metadata.creationTimestamp}{"\n"}{end}' |grep kube-system > kube-system-pod.csv

    for _LINE in $(cat kube-system-pod.csv)
    do
        _NS=$(echo $_LINE|cut -d, -f2)
        _POD=$(echo $_LINE|cut -d, -f3)

        _FILE="k_d_p_ns.${_NS}_pod.$_POD.out"
        echo "kubectl describe pod  -n $_NS $_POD" > ${_FILE}.cmd
        echo "kubectl describe pod  -n $_NS $_POD" > ${_FILE}
        kubectl describe pod  -n $_NS $_POD >> ${_FILE} 2>&1


        for _CONT in $(kubectl get pod $_POD -n $_NS -o jsonpath='{.spec.containers[*].name}')
        do

            _FILE="fid.X.ns.${_NS}_pod.${_POD}_cont.${_CONT}.out"
            echo "INFO: $_FILE"
            echo "kubectl logs -n "$_NS" "$_POD" -c "$_CONT" --timestamps" >  ${_FILE}.cmd
            echo "kubectl logs -n "$_NS" "$_POD" -c "$_CONT" --timestamps" >  ${_FILE}
            echo "kubectl logs -n "$_NS" "$_POD" -c "$_CONT" --timestamps" >>  ${_FILE}

            kubectl logs -n "$_NS" "$_POD" -c "$_CONT" --timestamps  >> ${_FILE} 2>&1

        done



        echo "INFO: getting image pull secrets for POD  $_NS/$_POD"
        _FILE=fid.${_FID}_ns.${_NS}_pod.${_POD}_imagePullSecrets.out
        echo "kubectl get pod -n $_NS $_POD -o jsonpath='{.spec.imagePullSecrets[*].name}'" > ${_FILE}.cmd 2>&1
        echo "kubectl get pod -n $_NS $_POD -o jsonpath='{.spec.imagePullSecrets[*].name}'" > ${_FILE} 2>&1
        _SECRETS=$(kubectl get pod -n "$_NS" "$_POD" -o jsonpath='{.spec.imagePullSecrets[*].name}' 2>&1)
        echo "$_SECRETS" >> ${_FILE}


        # 2. metadata (NOT decoded contents) for each referenced secret
	echo "HERE"
        for _SECRET in $_SECRETS
        do

            _FILE=fid.${_FID}_ns.${_NS}_pod.${_POD}_secretmeta.${_SECRET}.out
            echo "INFO: decoding and dumping secret in $_FILE"
            echo "kubectl get secret -n $_NS $_SECRET -o custom-columns=NAME:.metadata.name,TYPE:.type,CREATED:.metadata.creationTimestamp" > ${_FILE}.cmd 2>&1
            echo "kubectl get secret -n $_NS $_SECRET -o custom-columns=NAME:.metadata.name,TYPE:.type,CREATED:.metadata.creationTimestamp" > ${_FILE} 2>&1
            kubectl get secret -n "$_NS" "$_SECRET" -o custom-columns=NAME:.metadata.name,TYPE:.type,CREATED:.metadata.creationTimestamp  >> ${_FILE} 2>&1
	    kubectl get secret -n "$_NS" "$_SECRET" -o json |  jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"' >> ${_FILE} 2>&1
        done


    done

}

	






_PWD=$_TOP
cd $_PWD
collect_cluster_info

declare -A _NODELIST
export _NODELIST=($(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'))
echo "INFO: collecting data from ${_NODELIST[@]}"



_FILE=k_g_pa_FID.out
echo "kubectl  get pods   -A -LFUNCTION_ID -o wide" > ${_FILE}.cmd
echo "kubectl  get pods   -A -LFUNCTION_ID -o wide" >${_FILE}

_FILE=k_g_pa_FID_owide.out
echo "kubectl  get pods -A -LFUNCTION_ID -o wide" > ${_FILE}.cmd
echo "kubectl  get pods -A -LFUNCTION_ID -o wide" >> ${_FILE}
kubectl  get pods -A -LFUNCTION_ID -o wide >> ${_FILE}



_FILE=k_g_e_A.out
echo "kubectl  get events -A" > ${_FILE}.cmd
echo "kubectl  get events -A" > ${_FILE}
kubectl  get events -A >> ${_FILE}


_FILE=k_g_n_A_owide.out
echo "kubectl  get nodes -A -o wide" > ${_FILE}.cmd
echo "kubectl  get nodes -A -o wide" > ${_FILE}
kubectl  get nodes -A -o wide >> ${_FILE}



_FUNCTIONS=($(kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.labels.FUNCTION_ID}{"\n"}{end}' | grep -v '^$' | sort -u))
_PWD=$_TOP/functions/
mkdir -p $_PWD
cd $_PWD

for _DIR in ${_FUNCTIONS[@]}
do
	mkdir $_PWD/$_DIR
	cd $_PWD/$_DIR
	collect_pod_container_logs "$_DIR"
	#collect_pod_container_logs
	cd $_PWD
done


_PWD=$_TOP
cd $_PWD
collect_nvca_data

_PWD=$_TOP
cd $_PWD
collect_kube_system_data


_PWD=$_TOP
cd  $_PWD
	collect_containerd_logs
cd  $_PWD
	collect_kubelet_logs
cd  $_PWD
        collect_crictl_logs

