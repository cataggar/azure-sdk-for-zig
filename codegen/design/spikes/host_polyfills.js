// Minimal host-global polyfills for running the TypeSpec/TCGC bundle
// under QuickJS. In the real build these are provided by the Zig host.
(function (g) {
  if (typeof g.TextEncoder === "undefined") {
    g.TextEncoder = class TextEncoder {
      get encoding() { return "utf-8"; }
      encode(str) {
        str = String(str);
        const out = [];
        for (let i = 0; i < str.length; i++) {
          let c = str.charCodeAt(i);
          if (c >= 0xd800 && c <= 0xdbff && i + 1 < str.length) {
            const c2 = str.charCodeAt(i + 1);
            if (c2 >= 0xdc00 && c2 <= 0xdfff) { c = 0x10000 + ((c - 0xd800) << 10) + (c2 - 0xdc00); i++; }
          }
          if (c < 0x80) out.push(c);
          else if (c < 0x800) out.push(0xc0 | (c >> 6), 0x80 | (c & 0x3f));
          else if (c < 0x10000) out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f));
          else out.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 0x3f), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f));
        }
        return new Uint8Array(out);
      }
    };
  }
  if (typeof g.TextDecoder === "undefined") {
    g.TextDecoder = class TextDecoder {
      constructor(enc) { this.encoding = enc || "utf-8"; }
      decode(buf) {
        const b = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
        let s = "";
        for (let i = 0; i < b.length;) {
          let c = b[i++];
          if (c >= 0xf0) { c = ((c & 7) << 18) | ((b[i++] & 63) << 12) | ((b[i++] & 63) << 6) | (b[i++] & 63); }
          else if (c >= 0xe0) { c = ((c & 15) << 12) | ((b[i++] & 63) << 6) | (b[i++] & 63); }
          else if (c >= 0xc0) { c = ((c & 31) << 6) | (b[i++] & 63); }
          if (c > 0xffff) { c -= 0x10000; s += String.fromCharCode(0xd800 + (c >> 10), 0xdc00 + (c & 0x3ff)); }
          else s += String.fromCharCode(c);
        }
        return s;
      }
    };
  }
  if (typeof g.queueMicrotask === "undefined") {
    g.queueMicrotask = (cb) => Promise.resolve().then(cb);
  }
  if (typeof g.structuredClone === "undefined") {
    g.structuredClone = (v) => v === undefined ? undefined : JSON.parse(JSON.stringify(v));
  }
})(globalThis);

// Minimal crypto.subtle.digest("SHA-256") for the spike. The real Zig
// host provides this via std.crypto.hash.sha2.Sha256.
(function (g) {
  function sha256(bytes) {
    const K = [0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2];
    let h0=0x6a09e667,h1=0xbb67ae85,h2=0x3c6ef372,h3=0xa54ff53a,h4=0x510e527f,h5=0x9b05688c,h6=0x1f83d9ab,h7=0x5be0cd19;
    const l=bytes.length, bl=l*8;
    const withPad=[...bytes,0x80];
    while(withPad.length%64!==56) withPad.push(0);
    for(let i=7;i>=0;i--) withPad.push((bl/Math.pow(2,i*8))&0xff);
    const rotr=(x,n)=>(x>>>n)|(x<<(32-n));
    for(let j=0;j<withPad.length;j+=64){
      const w=new Array(64);
      for(let i=0;i<16;i++) w[i]=(withPad[j+i*4]<<24)|(withPad[j+i*4+1]<<16)|(withPad[j+i*4+2]<<8)|(withPad[j+i*4+3]);
      for(let i=16;i<64;i++){const s0=rotr(w[i-15],7)^rotr(w[i-15],18)^(w[i-15]>>>3);const s1=rotr(w[i-2],17)^rotr(w[i-2],19)^(w[i-2]>>>10);w[i]=(w[i-16]+s0+w[i-7]+s1)|0;}
      let a=h0,b=h1,c=h2,d=h3,e=h4,f=h5,gg=h6,hh=h7;
      for(let i=0;i<64;i++){
        const S1=rotr(e,6)^rotr(e,11)^rotr(e,25);const ch=(e&f)^((~e)&gg);const t1=(hh+S1+ch+K[i]+w[i])|0;
        const S0=rotr(a,2)^rotr(a,13)^rotr(a,22);const maj=(a&b)^(a&c)^(b&c);const t2=(S0+maj)|0;
        hh=gg;gg=f;f=e;e=(d+t1)|0;d=c;c=b;b=a;a=(t1+t2)|0;
      }
      h0=(h0+a)|0;h1=(h1+b)|0;h2=(h2+c)|0;h3=(h3+d)|0;h4=(h4+e)|0;h5=(h5+f)|0;h6=(h6+gg)|0;h7=(h7+hh)|0;
    }
    const out=new Uint8Array(32);const hs=[h0,h1,h2,h3,h4,h5,h6,h7];
    for(let i=0;i<8;i++){out[i*4]=(hs[i]>>>24)&0xff;out[i*4+1]=(hs[i]>>>16)&0xff;out[i*4+2]=(hs[i]>>>8)&0xff;out[i*4+3]=hs[i]&0xff;}
    return out;
  }
  if (typeof g.crypto === "undefined") g.crypto = {};
  if (!g.crypto.subtle) g.crypto.subtle = {
    async digest(algo, data) {
      const bytes = data instanceof Uint8Array ? data : new Uint8Array(data);
      return sha256(bytes).buffer;
    }
  };
})(globalThis);
