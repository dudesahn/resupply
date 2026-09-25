import inspect as rpcmod
from state import *
rpcmod.RPC='http://127.0.0.1:18545'
VOTER='0x11111111063874ce8dc6232cb5c1c849359476e6'
OLD='0xc5184cccf85b81eddc661330acb3e41bd89f34a1'
NEW='0x0837e20d15585b4ca5c1a3fcedccf8f72855cb56'
CTRL='0x0950000465476f4470e74aed93e7dd414012bb7d'
CLAIMER='0x1d9e146501cdcfad72afa90c1144181036ca5379'
RECEIVER='0xc9a9c21f8740684129d271ad1007e87e24858c59'
OWNER='0xfe11a5009f2121622271e7dd0fd470264e076af6'
START=1789044167
END=1790812800
DEADLINE=1790167367
results={}
def read(a,f,args=[]): return query(a,f,args)['decoded']
def send(a,sig,args=[],sender=None):
    sender=sender or rpc('eth_accounts',[])[0]
    h=rpc('eth_sendTransaction',[{'from':sender,'to':a,'data':cast('calldata',sig,*args),'gas':'0xe4e1c0'}])
    r=None
    for _ in range(120):
        r=rpc('eth_getTransactionReceipt',[h])
        if r: break
        time.sleep(.25)
    assert r and r['status']=='0x1',r
    return {'hash':h,'gas':int(r['gasUsed'],16),'logs':r['logs']}
def fails(a,sig,args=[],sender=None):
    try: rpc('eth_call',[{'from':sender or rpc('eth_accounts',[])[0],'to':a,'data':cast('calldata',sig,*args)},'latest'])
    except Exception as e: return str(e)
    raise AssertionError('expected revert')
def warp(t): rpc('evm_setNextBlockTimestamp',[t]); rpc('evm_mine',[])
def check(k,v): results[k]=v; print(k,json.dumps(v),flush=True)
if __name__=='__main__':
    rpc('evm_revert',['0x0'])
    initial=rpc('evm_snapshot',[])
    check('before_delay_revert',fails(VOTER,'executeProposal(uint256)',[29]))
    warp(START)
    check('can_execute_at_start',read(VOTER,'canExecute',[29]))
    olddebt=read(OLD,'totalBorrow'); newlimit=read(NEW,'borrowLimit')
    check('execution',send(VOTER,'executeProposal(uint256)',[29]))
    check('old_limit',read(OLD,'borrowLimit')); check('old_available',read(OLD,'totalDebtAvailable'))
    check('old_debt_unchanged',read(OLD,'totalBorrow')==olddebt)
    check('new_limit_unchanged_on_execution',read(NEW,'borrowLimit')==newlimit)
    check('new_ramp',read(CTRL,'pairLimits',[NEW]))
    check('approved',read(RECEIVER,'approvedClaimers',[CLAIMER]))
    check('unauthorized_claim_reverts',fails(CLAIMER,'claim()'))
    check('owner_claim_reverts_without_allowlist',fails(CLAIMER,'claim()',sender=OWNER))
    check('old_new_borrow_reverts',fails(OLD,'borrow(uint256,uint256,address)',[10**21,0,rpc('eth_accounts',[])[0]]))
    check('old_interest_still_works',call(OLD,'addInterest(bool)','true')!='0x')
    check('old_utilization',read(OLD,'currentUtilization'))
    applied=rpc('evm_snapshot',[])
    warp((START+END)//2)
    check('midpoint_keeper_update',send(CTRL,'updatePairBorrowLimit(address)',[NEW]))
    check('midpoint_limit',read(NEW,'borrowLimit'))
    warp(END)
    check('end_keeper_update',send(CTRL,'updatePairBorrowLimit(address)',[NEW]))
    check('end_limit',read(NEW,'borrowLimit'))
    assert int(read(NEW,'borrowLimit').split()[0])==40_000_000*10**18
    rpc('evm_revert',[applied])
    keeper=rpc('eth_accounts',[])[1]
    rpc('anvil_impersonateAccount',[OWNER]); rpc('anvil_setBalance',[OWNER,hex(10**20)])
    check('owner_can_delegate',send(CLAIMER,'setClaimer(address,bool)',[keeper,'true'],OWNER))
    token='0x419905009e4656fdc02418c7df35b1e61ed5f726'; recipient=rpc('eth_accounts',[])[2]
    before=int(call(token,'balanceOf(address)',recipient),16)
    check('delegate_can_claim_to_arbitrary_recipient',send(CLAIMER,'claimTo(address)',[recipient],keeper))
    check('recipient_rsup_received',int(call(token,'balanceOf(address)',recipient),16)-before)
    rpc('evm_revert',[initial]); last=rpc('evm_snapshot',[])
    warp(DEADLINE-1)
    check('execution_at_last_valid_time',send(VOTER,'executeProposal(uint256)',[29]))
    rpc('evm_revert',[last]); warp(DEADLINE+1)
    check('execution_after_deadline_reverts',fails(VOTER,'executeProposal(uint256)',[29]))
    (P/'simulation.json').write_text(json.dumps(results,indent=2))
