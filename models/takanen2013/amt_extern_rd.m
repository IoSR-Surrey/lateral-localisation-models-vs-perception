function [out,status] = amt_extern_rd(environment, directory, module, input, outstruct)
%AMT_EXTERN_RD Process external module using isolated temp directory.
%   This copy avoids collisions in parallel calls by using a unique run
%   directory per invocation for input/output handoff files.

switch environment
  case 'Python'
    [~,kv]=amt_configuration; % get default command to run python
    if isempty(kv.pythoncmd)
      error('Python Environment not available. Probed commands: python, python3');
    end
    python_cmd = kv.pythoncmd;
    env_python = getenv('VENV_PYTHON');
    if ~isempty(env_python)
      python_cmd = env_python;
    elseif evalin('base','exist(''venvPython'',''var'')')
      python_cmd = char(evalin('base','venvPython'));
    end

    act_path = pwd;
    env_dir = fullfile(amt_basepath,'environments', directory);
    cd(env_dir);

    run_dir = tempname;
    mkdir(run_dir);
    cleanup_obj = onCleanup(@() cleanup_run_dir(run_dir));

    if ~isempty(input)
      save(fullfile(run_dir,'input.mat'), '-struct', 'input', '-v7');
    end

    if isfile(module)
      module_path = module;
    else
      module_path = fullfile(env_dir, module);
    end

    disp(['AMT_EXTERN_RD using Python: ' python_cmd]);
    command = sprintf('"%s" "%s" "%s" "%s"', ...
      python_cmd, module_path, run_dir, env_dir);
    [stat,res] = system(command);

    status.status = stat;
    status.res = res;
    if stat ~= 0
      cd(act_path);
      amt_disp();
      amt_disp(res);
      error('AMT_EXTERN_RD: Something went wrong calling Python (see message above)');
    end

    if isempty(outstruct)
      out = [];
    else
      fn = fieldnames(outstruct);
      for ii = 1:length(fn)
        varname = fn{ii};
        var = outstruct.(varname);
        dim1 = var(1);
        if length(var)<2, dim2=1; else dim2=var(2); end
        if length(var)<3, dim3=1; else dim3=var(3); end
        for jj = 1:dim3
          filename = fullfile(run_dir,[varname int2str(jj) '.np']);
          f = fopen(filename,'r');
          if f == -1
            cd(act_path);
            error('AMT_EXTERN_RD: Could not open output file %s', filename);
          end
          out.(varname)(:,:,jj)=fread(f,[dim1 dim2],'double','n');
          fclose(f);
        end
      end
    end

    cd(act_path);
    clear cleanup_obj;
  otherwise
    error(['Environment ' environment ' is not supported']);
end

end

function cleanup_run_dir(run_dir)
if exist(run_dir,'dir')
  try
    rmdir(run_dir,'s');
  catch
    % Best-effort cleanup only.
  end
end
end
