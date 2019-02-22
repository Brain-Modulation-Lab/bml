function r = bml_xcorr(cfg, x, y)

% BML_XCORR calculates the cross correlation between ft_raw objects
% [deprecated]
%
% Use as
%   r = bml_xcorr(cfg, x, y)
%   r = bml_xcorr(x, y)
%   r = bml_xcorr(cfg, x)
%   r = bml_xcorr(x)
%
% x,y - FT_DATAYPE_RAW 
% cfg - configuration structure
% cfg.maxlag -  limits the lag range from –maxlag to maxlag. This syntax 
%    	accepts one or two input sequences. maxlag defaults to N – 1.
% cfg.scaleopt - additionally specifies a normalization option for the 
%     cross-correlation or autocorrelation. Any option other than 'none' 
%     (the default) requires x and y to have the same length.
%
% note: bml_xcorr matches x to y trial-by-trial. Use bml_conform_to to enforce trial
% matching by time. 
%
% returns a fieldtrip raw object, where time is mapped to lags

warning('bml_xcorr is deprecated function')

is_raw_cfg = all(ismember({'trial','time','label'},fieldnames(cfg)));
if nargin == 3
  assert((isempty(cfg) || isstruct(cfg)) && ~is_raw_cfg,'incorrect use of bml_xcorr');  
elseif nargin == 2
  if is_raw_cfg % case r = bml_xcorr(x, y)
    y=x;
    x=cfg;
    cfg=[];
  else % case r = bml_xcorr(cfg, x)
    y=[];
  end
elseif nargin == 1
  assert(is_raw_cfg,'incorrect use of bml_xcorr');
  y=[];
  x=cfg;
  cfg=[];
else
  error('incorrect use of bml_xcorr')
end
assert(all(ismember({'trial','time','label'},fieldnames(y))),'ft_datatype_raw expected as y');

maxlag = bml_getopt(cfg,'maxlag',[]);
scaleopt = bml_getopt(cfg,'scaleopt','none');

if ~isempty(y) % cross correlation
  assert(all(ismember({'trial','time','label'},fieldnames(y))),'ft_raw_expected as y');
  if numel(y.label)==1
    T = min(numel(x.trial),numel(y.trial));
    if numel(y.trial) ~= numel(x.trial)
      warning('x and y have different number of trials. Analyzing first %i trials',T)
    end
    
    %creating output ft_raw
    r = struct();
    r.label = x.label;
    r.time = cell(1,size(x.time,2));
    r.trial = cell(1,size(x.trial,2));
    
    for t=1:T
      x_Fs = round(1/mean(diff(x.time{t})),3,'significant');
      y_Fs = round(1/mean(diff(y.time{t})),3,'significant');
      if abs(x_Fs-y_Fs)/x_Fs > 0.001
        warning('Mismatched sampling rates Fs_x = %f ~= Fs_y = %f for trial %i',x_Fs,y_Fs,t)
      end
      
      if isempty(maxlag)
        maxlag_t = size(x.trial{t},2)-1;
      else
        maxlag_t = maxlag;
      end
      
      %doing first label for x
      [x_t_l1, x_t_lag1] = xcorr(x.trial{t}(1,:),y.trial{t}(1,:),maxlag_t,scaleopt);
      x_t_lag1 = x_t_lag1/x_Fs;
      %prealocating matrix
      r.trial{t} = zeros(size(x.trial{t},1),size(x_t_l1,2));
      r.trial{t}(1,:) = x_t_l1;
      r.time{t} = x_t_lag1;
      
      for l=2:numel(x.label)
        [x_t_l, x_t_lag] = xcorr(x.trial{t}(l,:),y.trial{t}(1,:),maxlag_t,scaleopt);
        x_t_lag = x_t_lag/x_Fs;
        if isequal(x_t_lag,x_t_lag1)
          r.trial{t}(l,:) = x_t_l;        
        else
          error('unequal lags for trial %t label %s',t,x.label{t}(l))
        end
      end
    end
  elseif numel(y.label) > 1  
    error('sorry, cross-correlation agains multiple channels not implemented yet\n Use single channel y')
  else
    error('y has no channels')
  end
else % autocorrelation
  error('sorry, autocorrelation mode not implemented yet')
end
