function h = pport(blk, id)
%PPORT Handle of the Simscape port with the given ID on a block.
%
%   h = pport(blk, id) reads the port list of a Simscape block from
%   InternalSimscapePortConfiguration and returns the handle of port id.
%   Examples of IDs: 'p' and 'n' (electrical), 'Ir' (irradiance input of
%   the Solar Cell block), 'DutyCycle' (input of the averaged converter).
%   For the Simulink-PS and PS-Simulink converter blocks, use 'in' and
%   'out'. For a Connection Port block, use 'port'.

ph = get_param(blk, 'PortHandles');
switch id
    case 'in',   h = ph.LConn(1); return
    case 'out',  h = ph.RConn(1); return
    case 'port', h = [ph.LConn ph.RConn]; h = h(1); return
end
cfg = jsondecode(get_param(blk, 'InternalSimscapePortConfiguration'));
sides = {'Left', 'LConn'; 'Right', 'RConn'};
for s = 1:2
    list = cfg.(sides{s,1});
    if isempty(list), continue; end
    if isstruct(list), list = num2cell(list); end
    for k = 1:numel(list)
        if strcmp(list{k}.id, id)
            h = ph.(sides{s,2})(k);
            return
        end
    end
end
error('pport:notFound', 'Port "%s" not found on %s.', id, getfullname(blk));
end
