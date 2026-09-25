import os,json,subprocess,pathlib,time,concurrent.futures
from urllib.parse import urlencode
P=pathlib.Path('/tmp/resupply-proposal-7e2094')
RPC=next(os.environ[k] for k in ['ETH_RPC_URL','ETHEREUM_MAINNET_RPC_URL','MAINNET_RPC_URL','ETH_RPC'] if os.environ.get(k))
def http(url,data=None):
    args=['curl','-sS','--max-time','45',url]
    if data is not None: args += ['-H','Content-Type: application/json','--data-binary',json.dumps(data)]
    r=subprocess.run(args,capture_output=True,text=True)
    if r.returncode: raise RuntimeError('HTTP client failed: '+str(r.returncode))
    return json.loads(r.stdout)
def rpc(method,params):
    r=http(RPC,{'jsonrpc':'2.0','id':1,'method':method,'params':params})
    if 'error' in r: raise RuntimeError(str(r['error']))
    return r['result']
def cast(*args): return subprocess.check_output(['cast',*map(str,args)],text=True).strip()
def call(addr,sig,*args,block='latest'):
    data=cast('calldata',sig,*args)
    return rpc('eth_call',[{'to':addr,'data':data},block])
def source(addr):
    f=P/(addr.lower()+'.json')
    if f.exists(): return json.loads(f.read_text())
    r=http('https://api.etherscan.io/v2/api?'+urlencode({'chainid':1,'module':'contract','action':'getsourcecode','address':addr,'apikey':os.environ['ETHERSCAN_API_KEY']}))
    if r.get('status')!='1': raise RuntimeError('Etherscan failed: '+str(r.get('result')))
    d=r['result'][0]; f.write_text(json.dumps(d,indent=2))
    raw=d['SourceCode']; out=P/'sources'/addr.lower(); out.mkdir(parents=True,exist_ok=True)
    if raw.startswith('{{'): raw=raw[1:-1]
    if raw.startswith('{'):
        j=json.loads(raw)
        for name,v in j.get('sources',j).items():
            if isinstance(v,dict) and 'content' in v:
                target=out/name
                if not target.resolve().is_relative_to(out.resolve()): continue
                target.parent.mkdir(parents=True,exist_ok=True); target.write_text(v['content'])
    elif raw: (out/(d['ContractName']+'.sol')).write_text(raw)
    return d
if __name__=='__main__':
    payload=json.loads((P/'payload.json').read_text())
    addresses=[payload['voter']]+[x['target'] for x in payload['actions']]+['0x0837e20d15585b4ca5c1a3fcedccf8f72855cb56','0x1d9e146501cdcfad72afa90c1144181036ca5379']
    for addr in addresses:
        d=source(addr)
        print(addr,json.dumps({k:d.get(k) for k in ['ContractName','CompilerVersion','Proxy','Implementation','ConstructorArguments']}))
        time.sleep(.3)
