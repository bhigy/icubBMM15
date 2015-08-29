function points = makeBox(point, range, step)

spot = [point]; 

%spotBig(1,:) = spot;

if ~exist('step')
    xrange = [-range range]/2.0;
    yrange = [-range range];
    zrange = yrange;
else 
    xrange = [-range:step:range]/2.0; 
    yrange = -range:step:range;
    zrange = yrange;
end 

i=1;
for xx = xrange
    for yy = yrange
        for zz = zrange
            spotBig(i,:) = [spot(1)+xx, spot(2)+yy, spot(3)+zz];
            i=i+1;
        end 
    end 
end 

points = spotBig;

            
           
    
    
    