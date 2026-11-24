function [st, D, fin] = gmppt_ideab(st, p, V, I)
%GMPPT_IDEAB One step of Idea B refined: DIRECT global stage, then the
%ceiling check with the corner split.
%
%   [st, D, fin] = gmppt_ideab(st, p, V, I) follows the interface of
%   gmppt_search.m. This method is an implementation of published parts:
%
%     Part 1. The DIRECT search of Nguyen and Low (IEEE Trans. Ind.
%       Electron. 57(10), 2010), up to the end of its globally biased
%       stage: the first samples, the shading test and, if the test finds
%       shading, the global cycles with the skip rules. gmppt_direct.m
%       does this part with globalOnly = true. The two extra global
%       cycles and the locally biased stage of DIRECT do not run.
%     Part 2. The ceiling check of gmppt_ceiling.m on all the DIRECT
%       samples. The inequality P <= V1 * I2 is that of Boztepe et al.
%       (2014) and Wang, Li and Ruan (2016). The check splits each open
%       gap at its corner duty. The corner split is the projection step
%       of the polyblock algorithm (Tuy 2000; Zhang, Qian and Huang 2012).
%       With p.mg_on = 1 (default), the check also treats the two margins
%       between the DIRECT samples and the ends of the range as gaps, with
%       ceilings from p.mg_Voc and p.mg_Isc. An open margin is closed by a
%       probe at p.Dlo or p.Dhi (gmppt_ceiling.m). Added on 2026-11-21
%       with the approval of the user.
%     Hand-over at the duty of the best sample.
%
%   st.mode is 0 during part 1 and 1 during part 2. st.cert and
%   st.certAll hold the certificate ratios at the end (gmppt_ceiling.m).

if st.mode == 0
    [st, D, fin, gdone] = gmppt_direct(st, p, V, I, true);
    if fin
        st.end_kind = 0;                   % The store is full: shared local stage
        st.end_step = 0;
        return
    end
    if ~gdone
        return                             % The DIRECT part continues
    end
    st.mode = 1;                           % The last DIRECT sample is in the store
else
    st = gmppt_store_add(st, st.Dp, V, I, 0);
end
[st, D, fin] = gmppt_ceiling(st, p, true, p.mg_on == 1);
if fin
    st.end_kind = 0;                       % No ending of its own: shared local stage
    st.end_step = 0;
end
end
