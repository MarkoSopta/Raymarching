﻿// Sphere
// s: radius
float sdSphere(float3 p, float s)
{
	return length(p) - s;
}

           float sminCubic( float a, float b, float k )
{
                float h = max( k-abs(a-b), 0.0 )/k;
                return min( a, b ) - h*h*k*(1.0/4.0);
}

float sdTorus( float3 p, float2 t )
{
  float2 q = float2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

float sdPlane( float3 p, float4 n)
{
  // n must be normalized
  return dot(p,n.xyz)+n.w ;
}

//Rounded  Box

float sdRoundedbox( in float3 p, in float3 b , in float r){
float3 q = abs(p) - b;
return min(max(q.x,max(q.y,q.z)),0.0) + length(max(q,0.0))-r;
}




// Box
// b: size of box in x/y/z
float sdBox(float3 p, float3 b)
{
	float3 d = abs(p) - b;
	return min(max(d.x, max(d.y, d.z)), 0.0) +
		length(max(d, 0.0));
}

// SMOOTH BOOLEAN OPS
float4 opUS( float4 d1, float4 d2, float k ) 
{
    float h = clamp( 0.5 + 0.5*(d2.w-d1.w)/k, 0.0, 1.0 );	
	float3 color = lerp(d2.rgb, d1.rgb, h);
	float dist =  lerp( d2.w, d1.w, h ) - k*h*(1.0-h);
	return float4 (color, dist);
}

float opSS( float d1, float d2, float k ) 
{
    float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
    return lerp( d2, -d1, h ) + k*h*(1.0-h); 
}

float opIS( float d1, float d2, float k ) 
{
    float h = clamp( 0.5 - 0.5*(d2-d1)/k, 0.0, 1.0 );
    return lerp( d2, d1, h ) + k*h*(1.0-h); 
}

// BOOLEAN OPERATORS //

// Union
float4 opU(float4 d1, float4 d2)
{
	return (d1.w < d2.w) ? d1 : d2;
}

// Subtraction
float opS(float d1, float d2)
{
	return max(-d1, d2);
}

// Intersection
float opI(float d1, float d2)
{
	return max(d1, d2);
}

// Mod Position Axis
float pMod1 (inout float p, float size)
{
	float halfsize = size * 0.5;
	float c = floor((p+halfsize)/size);
	p = fmod(p+halfsize,size)-halfsize;
	p = fmod(-p+halfsize,size)-halfsize;
	return c;
}