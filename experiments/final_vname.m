function name = final_vname(v)
%FINAL_VNAME Name of a variant of the final tests (fields alg and loc, see
%   final_variant.m), for the tables. Added on 2026-11-23.

algName = {'P&O', 'INC', 'DIRECT', 'Idea B', 'Idea C', 'PSO', 'GWO'};
locName = {'P&O', 'VS-INC', 'Parabolic', 'INC'};
if v.alg <= 2
    name = [algName{v.alg} ' from start-up'];
elseif v.loc == 5
    name = [algName{v.alg} ' (paper)'];
else
    name = sprintf('%s + %s', algName{v.alg}, locName{v.loc});
end
end
