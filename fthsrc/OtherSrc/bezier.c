int interpolate( int from , int to , float percent )
{
    int difference = to - from;
    return from + ( difference * percent );
}    

//Quadratic
for( float i = 0 ; i < 1 ; i += 0.01 )
{
    // The Green Line
    xa = interpolate( x1 , x2 , i );
    ya = interpolate( y1 , y2 , i );
    xb = interpolate( x2 , x3 , i );
    yb = interpolate( y2 , y3 , i );

    // The Black Dot
    x = interpolate( xa , xb , i );
    y = interpolate( ya , yb , i );
    
    drawPixel( x , y , COLOR_RED );
}

//Cubic
for( float i = 0 ; i < 1 ; i += 0.01 )
{
    // The Green Lines
    xa = getPt( x1 , x2 , i );
    ya = getPt( y1 , y2 , i );
    xb = getPt( x2 , x3 , i );
    yb = getPt( y2 , y3 , i );
    xc = getPt( x3 , x4 , i );
    yc = getPt( y3 , y4 , i );

    // The Blue Line
    xm = getPt( xa , xb , i );
    ym = getPt( ya , yb , i );
    xn = getPt( xb , xc , i );
    yn = getPt( yb , yc , i );

    // The Black Dot
    x = getPt( xm , xn , i );
    y = getPt( ym , yn , i );

    drawPixel( x , y , COLOR_RED );
}


