function raw_roi = s2raw(roi)

% S2RAW calculates raw sample from s coords in roi

%exapanding partial file coordinates
for i=2:height(roi)
  if roi.s1(i) > 1
    roi.t1(i) = bml_idx2time(roi(i,:),1);
    roi.s1(i) = 1;
  end
end

for i=1:(height(roi)-1)
  if roi.s2(i) < roi.nSamples(i)
    roi.t2(i) = bml_idx2time(roi(i,:),roi.nSamples(i));
    roi.s2(i) = roi.nSamples(i);
  end
end

cs = cumsum(roi.s2-roi.s1) + roi.s1(1);
cs = cs + (0:(height(roi)-1))';
cs = [0; cs(1:end-1)];
roi.raw1 = roi.s1 + cs;
roi.raw2 = roi.s2 + cs;

raw_roi = roi;
