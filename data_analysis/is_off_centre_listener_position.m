function tf = is_off_centre_listener_position(position_id, listexp_id)
%IS_OFF_CENTRE_LISTENER_POSITION True for off-centre listener position plots.
%
%   tf = is_off_centre_listener_position(position_id)
%   tf = is_off_centre_listener_position(position_id, listexp_id)
%
% Recognises off-centre seating (desena2013, frank2013), llado2026 P1–P3,
% and pooled/combined off-centre plot labels.

tf = false;

if nargin >= 1 && ~isempty(position_id)
    pos = lower(string(position_id));
    if pos == "off_centre" || pos == "off-centre" || ismember(pos, ["p1", "p2", "p3"])
        tf = true;
        return
    end
    if pos == "centre" || pos == "center" || pos == "p0"
        tf = false;
        return
    end
end

if nargin < 2 || isempty(listexp_id)
    return
end

lid = lower(string(listexp_id));
if lid == "off_centre"
    tf = true;
    return
end
if contains(lid, "off-centre") || contains(lid, "off_centre")
    tf = true;
    return
end
if contains(lid, " — p1") || contains(lid, " — p2") || contains(lid, " — p3")
    tf = true;
end
end
