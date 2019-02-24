function ADTableLength(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

function AutoDrive:BoxesIntersect(a,b)
	local polygons = {a, b};
	local minA, maxA,minB,maxB;

	for i,polygon in pairs(polygons) do

		-- for each polygon, look at each edge of the polygon, and determine if it separates
		-- the two shapes

		for i1, corners in pairs(polygon) do
			--grab 2 vertices to create an edge
			local i2 = (i1%4 + 1) ;
			local p1 = polygon[i1];
			local p2 = polygon[i2];

			-- find the line perpendicular to this edge
			local normal = { x =  p2.z - p1.z, z = p1.x - p2.x };

			minA = nil;
			maxA = nil;
			-- for each vertex in the first shape, project it onto the line perpendicular to the edge
			-- and keep track of the min and max of these values

			for j,corner in pairs(polygons[1]) do
				local projected = normal.x * corner.x + normal.z * corner.z;
				if minA == nil or projected < minA then
					minA = projected;
				end;
				if maxA == nil or projected > maxA then
					maxA = projected;
				end;
			end;

			--for each vertex in the second shape, project it onto the line perpendicular to the edge
			--and keep track of the min and max of these values
			minB = nil;
			maxB = nil;
			for j, corner in pairs(polygons[2]) do
				projected = normal.x * corner.x + normal.z * corner.z;
				if minB == nil or projected < minB then
					minB = projected;
				end;
				if maxB == nil or projected > maxB then
						maxB = projected;
				end;
			end;
			-- if there is no overlap between the projects, the edge we are looking at separates the two
			-- polygons, and we know there is no overlap
			if maxA < minB or maxB < minA then
				--print("polygons don't intersect!");
				return false;
			end;
		end;
	end;

	--print("polygons intersect!");
	return true;
end

function string:split(sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

function AutoDrive:printMessage(newMessage)
	AutoDrive.print.nextMessage = newMessage;
end;

function ADBoolToString(value)
	if value == true then
		return "true";
	end;
	return "false";
end;