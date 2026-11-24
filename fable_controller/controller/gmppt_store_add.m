function st = gmppt_store_add(st, D, V, I, lev)
%GMPPT_STORE_ADD Add one sample to the sample store of the global search.
%
%   st = gmppt_store_add(st, D, V, I, lev) adds the sample (D, V, I) as
%   entry st.n + 1. lev is the DIRECT level of the sample. The other
%   methods give 0.
%
%   The function also keeps two items up to date:
%     st.ord  the indices of the samples in the order of rising duty. The
%             function puts the new index at its place (one step of an
%             insertion sort), so no call of sort is necessary.
%     st.ib   the index of the sample with the highest power. If two
%             samples have the same power, the sample that came first
%             stays the best sample.
%
%   If the store is full, the function does not change st. The caller
%   must end the search before this occurs.

n = st.n + 1;
if n > numel(st.D)
    return
end
st.n      = n;
st.D(n)   = D;
st.V(n)   = V;
st.I(n)   = I;
st.P(n)   = V * I;
st.lev(n) = lev;

% Move the indices of the higher duties up by one place.
k = n;
while k > 1 && st.D(st.ord(k-1)) > D
    st.ord(k) = st.ord(k-1);
    k = k - 1;
end
st.ord(k) = n;

if n == 1 || st.P(n) > st.P(st.ib)
    st.ib = n;
end
end
