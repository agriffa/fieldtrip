function varargout = peerget(jobid, varargin)

% PEERGET get the output arguments after the remote job has been executed.
%
% Use as
%   argout = peerget(jobid, ...)
%
% Optional arguments can be specified in key-value pairs and can include
%   StopOnError    = boolean (default = true)
%   timeout        = number, in seconds (default = 1)
%   sleep          = number, in seconds (default = 0.01)
%   output         = string, 'varargout' or 'cell' (default = 'varargout')
%   diary          = string, can be 'always', 'warning', 'error' (default = 'error')
%
% See also PEERFEVAL, PEERCELLFUN

% -----------------------------------------------------------------------
% Copyright (C) 2010, Robert Oostenveld
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/
% -----------------------------------------------------------------------

% the following are to speed up subsequent calls
persistent previous_varargin previous_timeout previous_sleep previous_output previous_diary previous_StopOnError

if isequal(previous_varargin, varargin)
  % prevent the ft_getopt function from being called, because it is slow
  % reuse the values from the previous call
  timeout     = previous_timeout;
  sleep       = previous_sleep;
  output      = previous_output;
  diary       = previous_diary;
  StopOnError = previous_StopOnError;
else
  % get the optional arguments
  timeout     = ft_getopt(varargin, 'timeout',     1.000);
  sleep       = ft_getopt(varargin, 'sleep',       0.010);
  output      = ft_getopt(varargin, 'output',      'varargout');
  diary       = ft_getopt(varargin, 'diary',       'error');
  StopOnError = ft_getopt(varargin, 'StopOnError', true);
end

% keep track of the time
stopwatch = tic;

success = false;
while ~success && toc(stopwatch)<timeout

  joblist = peer('joblist');
  sel = find([joblist.jobid]==jobid);

  if ~isempty(sel)
    [argout, options] = peer('get', jobid);
    peer('clear', jobid);
    success = true;
  else
    % the job results have not arrived yet
    % wait a little bit and try again
    pause(sleep);
    continue
  end

end % while 

if success

  % look at the optional arguments
  elapsed     = ft_getopt(options, 'elapsed');
  warn        = ft_getopt(options, 'lastwarn');
  err         = ft_getopt(options, 'lasterr');
  diarystring = ft_getopt(options, 'diary');

  if strcmp(diary, 'error') && ~isempty(err)
    if ~isempty(strfind(err, 'could not start the matlab engine')) || ...
       ~isempty(strfind(err, 'failed to execute the job (argin)')) || ...
       ~isempty(strfind(err, 'failed to execute the job (optin)'))
      % this is due to a license or a memory problem, and is dealt with in peercellfun
      closeline = false;
    else
      fprintf('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n');
      fprintf('%% an error was detected, the diary output of the remote execution follows \n');
      fprintf('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n');
      fprintf('%s', diarystring);
      closeline = true;
    end
  elseif strcmp(diary, 'warning') && ~isempty(warn)
    fprintf('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n');
    fprintf('%% a warning was detected, the diary output of the remote execution follows\n');
    fprintf('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n');
    fprintf('%s', diarystring);
    closeline = true;
  elseif strcmp(diary, 'always')
    fprintf('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n');
    fprintf('%% the output of the remote execution follows\n');
    fprintf('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n');
    fprintf('%s', diarystring);
    closeline = true;
  else
    closeline = false;
  end
  if ~isempty(warn)
    warning(warn);
  end
  if ~isempty(err)
    if ischar(err)
      % it only contains the description
      if StopOnError
        error(err);
      else
        warning('error during remote execution: %s', err);
      end
    else
      ws = warning('off', 'MATLAB:structOnObject');
      err = struct(err);
      warning(ws);
      if StopOnError
        % it contains the full details
        rethrow(err);
      else
        warning('error during remote execution: %s', err.message);
      end
    end
  end % ~isempty(err)
  if closeline
    fprintf('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n');
  end

  switch output
  case 'varargout'
    % return the output arguments, the options cannot be returned
    varargout = argout;
  case 'cell'
    % return the output arguments and the options
    varargout{1} = argout;
    varargout{2} = options;
  otherwise
    error('invalid output option');
  end

else 
  warning('the job results are not yet available');
  switch output
  case 'varargout'
    % return empty output arguments
    varargout = cell(1, nargout);
  case 'cell'
    % return the output arguments and the options as empty cells
    varargout{1} = {};
    varargout{2} = {};
  otherwise
    error('invalid output option');
  end
end

% remember the input arguments to speed up subsequent calls
previous_varargin    = varargin;
previous_timeout     = timeout;
previous_sleep       = sleep;
previous_output      = output;
previous_diary       = diary;
previous_StopOnError = StopOnError;
