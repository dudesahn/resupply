from inspect import *
def typ(x):
    return '('+','.join(typ(y) for y in x['components'])+')'+x['type'][5:] if x['type'].startswith('tuple') else x['type']
def query(addr,name,args=[],block='latest'):
    abi=json.loads(source(addr)['ABI']); a=next(x for x in abi if x['type']=='function' and x['name']==name and len(x['inputs'])==len(args))
    sig=name+'('+','.join(typ(x) for x in a['inputs'])+')'
    raw=call(addr,sig,*args,block=block)
    dec=cast('abi-decode','x()('+','.join(typ(x) for x in a['outputs'])+')',raw) if a['outputs'] else raw
    return {'raw':raw,'decoded':dec}
if __name__=='__main__':
    payload=json.loads((P/'payload.json').read_text()); latest=rpc('eth_blockNumber',[]); block=rpc('eth_getBlockByNumber',[latest,False]); (P/'snapshot_block.json').write_text(json.dumps(block,indent=2)); jobs=[]
    pair_fields=['name','version','core','owner','registry','collateral','underlying','convexBooster','convexPid','borrowLimit','totalBorrow','totalCollateral','totalDebtAvailable','maxLTV','liquidationFee','mintFee','protocolRedemptionFee','redemptionWriteOff','rateCalculator','exchangeRateInfo','minimumBorrowAmount','minimumLeftoverDebt','minimumRedemption','getPairAccounting']
    for addr in ['0xc5184cccf85b81eddc661330acb3e41bd89f34a1','0x0837e20d15585b4ca5c1a3fcedccf8f72855cb56']:
        for field in pair_fields: jobs.append((addr,field,[],latest))
        for field in ['borrowLimit','totalBorrow']: jobs.append((addr,field,[],hex(payload['block']-1)))
    for field,args in [('proposalData',[29]),('getProposalData',[29]),('canExecute',[29]),('votingPeriod',[]),('executionDelay',[]),('EXECUTION_DEADLINE',[]),('core',[])]: jobs.append((payload['voter'],field,args,latest))
    for field,args in [('pairLimits',['0x0837e20d15585b4ca5c1a3fcedccf8f72855cb56']),('pairLimits',['0xc5184cccf85b81eddc661330acb3e41bd89f34a1']),('previewNewBorrowLimit',['0x0837e20d15585b4ca5c1a3fcedccf8f72855cb56']),('owner',[])]: jobs.append(('0x0950000465476f4470e74aed93e7dd414012bb7d',field,args,latest))
    for field,args in [('owner',[]),('RECEIVER',[])]: jobs.append(('0x1d9e146501cdcfad72afa90c1144181036ca5379',field,args,latest))
    for field,args in [('owner',[]),('core',[]),('name',[]),('govToken',[]),('emissionsController',[]),('getReceiverId',[]),('claimableEmissions',[]),('initialized',[]),('approvedClaimers',['0x1d9e146501cdcfad72afa90c1144181036ca5379'])]: jobs.append(('0xc9a9c21f8740684129d271ad1007e87e24858c59',field,args,latest))
    results={}
    def job(j):
        addr,name,args,b=j; key=addr+':'+name+'('+','.join(map(str,args))+')@'+b
        try: return key,query(addr,name,args,b)
        except Exception as e: return key,{'error':str(e)}
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as ex:
        for k,v in ex.map(job,jobs): results[k]=v; print(k,v.get('decoded',v))
    (P/'state.json').write_text(json.dumps(results,indent=2))
