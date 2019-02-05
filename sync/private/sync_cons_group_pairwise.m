function delta_t_M = sync_cons_group_pairwise(roi,timewarp,samplevar)

%doing all pairwise consolidations
n=height(roi);
delta_t_M = zeros(n);
for i=1:n
  for j=1:n
    [~,max_delta_t,~] = sync_cons_group(roi([i,j],:),timewarp,samplevar);
    delta_t_M(i,j)=max_delta_t;
  end
end

