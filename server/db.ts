import pg from 'pg';
export const pool = new pg.Pool({host:'/var/run/postgresql',database:'adaptive_deploy',user:'adaptive-web',max:5,connectionTimeoutMillis:3000});
