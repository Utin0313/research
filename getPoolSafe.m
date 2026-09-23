function pool = getPoolSafe()
if exist("gcp","file") && license('test','distrib_computing_toolbox')
  pool = gcp;
  if isempty(pool)
    pool = parpool;
  end
else
  pool = [];
end
end