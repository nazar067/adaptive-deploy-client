import {randomBytes,scrypt,timingSafeEqual,createHash} from 'node:crypto';
const params={N:32768,r:8,p:3,maxmem:64*1024*1024};
function derive(password:string,salt:Buffer):Promise<Buffer>{return new Promise((resolve,reject)=>scrypt(password,salt,64,params,(e,key)=>e?reject(e):resolve(key)));}
export async function hashPassword(password:string){const salt=randomBytes(16);return salt.toString('hex')+':'+(await derive(password,salt)).toString('hex');}
export async function checkPassword(password:string,stored:string){const [salt,key]=stored.split(':');if(!/^[a-f0-9]{32}$/.test(salt||'')||!/^[a-f0-9]{128}$/.test(key||''))return false;return timingSafeEqual(await derive(password,Buffer.from(salt,'hex')),Buffer.from(key,'hex'));}
export const tokenHash=(token:string)=>createHash('sha256').update(token).digest('hex');
