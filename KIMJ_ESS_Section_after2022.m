clc; clear; close all

%% 1. 기본 경로 및 날짜 폴더 설정
baseDir    = 'G:\공유 드라이브\BSL_Data2\한전_김제ESS';
kimjFolder = '202206_KIMJ';
basePath   = fullfile(baseDir, kimjFolder);

% 폴더 내의 모든 폴더 목록 가져오기 ('.', '..' 제외)
allItems    = dir(basePath);
folderNames = {allItems([allItems.isdir]).name};
folderNames = folderNames(~ismember(folderNames, {'.', '..'}));

% 폴더명이 8자리 숫자(YYYYMMDD) 형식인 경우만 선택
isDateFolder = cellfun(@(x) ~isempty(regexp(x, '^\d{8}$', 'once')), folderNames);
dateFolders  = sort(folderNames(isDateFolder));

% 특정 주간 기간 설정
weekStart = '20220601';
weekEnd   = '20220630';
weekFolders = dateFolders(cellfun(@(x) (str2double(x) >= str2double(weekStart)) && ...
                                       (str2double(x) <= str2double(weekEnd)), dateFolders));

% 파일명 패턴 (예: 20210608_LGCHEM_BSC*.csv)
filePatternTemplate = 'JXR_BSC_Section_%s*.csv';

% 헤더(메타데이터)가 포함된 줄 번호 (파일 상에서 5행까지가 헤더 부분)
n_hd = 2;

% 그룹 데이터를 저장할 테이블 초기화 (모든 파일의 fullData를 누적)
T_group = table();

%% 2. 각 날짜 폴더 내 파일 처리
for i = 1:length(weekFolders)
    currDate   = weekFolders{i};
    data_folder = fullfile(baseDir, kimjFolder, currDate);
    
    % 현재 날짜 폴더 내 파일 목록 생성
    filePattern = fullfile(data_folder, sprintf(filePatternTemplate, currDate));
    fileList    = dir(filePattern);
    
    for j = 1:length(fileList)
        fname    = fileList(j).name;
        fullPath = fullfile(fileList(j).folder, fname);
        
        %% 2-1. 미리보기 데이터 읽기 (첫 5줄)
        % readcell는 자동 변환 없이 원시 셀 데이터를 가져옵니다.
        % (열 개수가 많을 수 있으므로 A1:ZZ5 등 넉넉하게 범위를 지정)
        previewData = readcell(fullPath, 'Range', 'A1:ZZ5');
        
        % 4행의 셀 데이터를 문자열 배열로 변환한 후, 온라인/총합 열 인덱스를 찾습니다.
        headerLine = string(previewData(4, :));
        onlineCols = find( contains(headerLine, "[Online]") );
        totalCols  = find( contains(headerLine, "[Total]") );
        
        % 5행의 데이터를 변수명으로 사용 (문자열 배열로 변환)
        variableNames = string(previewData(5, :));
        % 유효한 MATLAB 변수명으로 변환 (특수문자, 공백 제거)
        variableNames = matlab.lang.makeValidName(variableNames);
        % 중복되는 변수명이 있을 경우 고유하게 만듭니다.
        variableNames = matlab.lang.makeUniqueStrings(cellstr(variableNames));
        
        %% 2-2. 전체 데이터 읽기 (헤더 부분은 제외)
        % 'TextType','char' 옵션을 추가하여 텍스트 데이터를 char 배열로 읽습니다.
        fullDataAll = readtable(fullPath, 'FileType', 'text', ...
            'ReadVariableNames', false, 'TextType','char');
        if height(fullDataAll) <= n_hd
            error('파일 %s 에 데이터가 부족합니다.', fname);
        end
        % 헤더 관련 줄(앞 n_hd줄) 제거 후 실제 데이터만 추출
        fullData = fullDataAll(n_hd+1:end, :);
        
        % 미리보기에서 얻은 고유한 변수명을 전체 데이터에 적용
        fullData.Properties.VariableNames = variableNames;
        
        %% 2-3. 온라인/총합 데이터 분리 및 저장 (필요에 따라 별도 저장)
        onlineData = fullData(:, onlineCols);
        totalData  = fullData(:, totalCols);
        
        fprintf('Processing file: %s\n', fname);
        fprintf('- Online data columns: %s\n', strjoin(variableNames(onlineCols), ', '));
        fprintf('- Total data columns: %s\n', strjoin(variableNames(totalCols), ', '));
        
        onlineSavePath = fullfile(data_folder, ['Online_', fname]);
        totalSavePath  = fullfile(data_folder, ['Total_', fname]);
        
        writetable(onlineData, onlineSavePath);
        writetable(totalData, totalSavePath);
        
        fprintf('- Online data saved to: %s\n', onlineSavePath);
        fprintf('- Total data saved to: %s\n', totalSavePath);
        
        %% 2-4. 그룹 데이터에 누적 (T_group)
        if isempty(T_group)
            T_group = fullData;
        else
            T_group = vertcat(T_group, fullData);
        end
    end
end

%% time-SOC plot
if ismember('Time', T_group.Properties.VariableNames)
    try
        % 데이터가 char 배열이면 datetime 변환 시 cell로 변환 후 사용
        if iscell(T_group.Time)
            T_group.Time = datetime(T_group.Time, 'InputFormat', 'yyyy-MM-dd HH:mm');
        else
            T_group.Time = datetime(T_group.Time, 'InputFormat', 'yyyy-MM-dd HH:mm');
        end
    catch
        warning('Time 열의 형식 변환에 문제가 있습니다. 플롯 전에 형식을 확인하세요.');
    end
else
    warning('T_group에 ''Time'' 열이 없습니다.');
end

if all(ismember({'AverageSOC___', 'AverageSOC____1'}, T_group.Properties.VariableNames))
    figure;
    plot(T_group.Time, T_group.("AverageSOC___"),'-r');
    hold on;
    plot(T_group.Time, T_group.("AverageSOC____1"),'--b');
    xlabel('Time');
    ylabel('Average SOC(%)');
    title(sprintf('Time vs Average SOC(%%) for Week %s ~ %s', weekFolders{1}, weekFolders{end}));
    legend('Average SOC online', 'Average SOC total', 'Location', 'best');
    grid on;
else
    warning('T_group에 ''Average SOC(%)'' 또는 ''Average SOC(%)_1'' 열이 존재하지 않습니다.');
end

%% time-Current

if ismember('Time', T_group.Properties.VariableNames)
    try
        % 데이터가 char 배열이면 datetime 변환 시 cell로 변환 후 사용
        if iscell(T_group.Time)
            T_group.Time = datetime(T_group.Time, 'InputFormat', 'yyyy-MM-dd HH:mm');
        else
            T_group.Time = datetime(T_group.Time, 'InputFormat', 'yyyy-MM-dd HH:mm');
        end
    catch
        warning('Time 열의 형식 변환에 문제가 있습니다. 플롯 전에 형식을 확인하세요.');
    end
else
    warning('T_group에 ''Time'' 열이 없습니다.');
end

if all(ismember({'DCCurrent_A_', 'AverageSOC____1'}, T_group.Properties.VariableNames))
    figure;
    plot(T_group.Time, T_group.("DCCurrent_A_"),'-b');
    xlabel('Time');
    ylabel('Current');
    title(sprintf('Time vs Current for Week %s ~ %s', weekFolders{1}, weekFolders{end}));
    legend('DC Current', 'Location', 'best');
    grid on;
end
%% time-C_V_sum

if ismember('Time', T_group.Properties.VariableNames)
    try
        % 데이터가 char 배열이면 datetime 변환 시 cell로 변환 후 사용
        if iscell(T_group.Time)
            T_group.Time = datetime(T_group.Time, 'InputFormat', 'yyyy-MM-dd HH:mm');
        else
            T_group.Time = datetime(T_group.Time, 'InputFormat', 'yyyy-MM-dd HH:mm');
        end
    catch
        warning('Time 열의 형식 변환에 문제가 있습니다. 플롯 전에 형식을 확인하세요.');
    end
else
    warning('T_group에 ''Time'' 열이 없습니다.');
end

if all(ismember({'AverageC_V_Sum_V_', 'AverageC_V_Sum_V__1'}, T_group.Properties.VariableNames))
    figure;
    plot(T_group.Time, T_group.("AverageC_V_Sum_V_"),'-r');
    hold on;
    plot(T_group.Time, T_group.("AverageC_V_Sum_V__1"),'--b');
    xlabel('Time');
    ylabel('AverageC_V_Sum_V');
    title(sprintf('Time vs AverageC_V_Sum_V for Week %s ~ %s', weekFolders{1}, weekFolders{end}));
    legend('AverageC V Sum V', 'AverageC V Sum V total', 'Location', 'best');
    grid on;

end

% time-average cell voltage

if ismember('Time', T_group.Properties.VariableNames)
    try
        % 데이터가 char 배열이면 datetime 변환 시 cell로 변환 후 사용
        if iscell(T_group.Time)
            T_group.Time = datetime(T_group.Time, 'InputFormat', 'yyyy-MM-dd HH:mm');
        else
            T_group.Time = datetime(T_group.Time, 'InputFormat', 'yyyy-MM-dd HH:mm');
        end
    catch
        warning('Time 열의 형식 변환에 문제가 있습니다. 플롯 전에 형식을 확인하세요.');
    end
else
    warning('T_group에 ''Time'' 열이 없습니다.');
end

if all(ismember({'AverageC_V__V_', 'AverageC_V__V__1'}, T_group.Properties.VariableNames))
    figure;
    plot(T_group.Time, T_group.("AverageC_V__V_"),'-r');
    hold on;
    plot(T_group.Time, T_group.("AverageC_V__V__1"),'--b');
    xlabel('Time');
    ylabel('Average cell voltage');
    title(sprintf('Time vs Average cell voltage for Week %s ~ %s', weekFolders{1}, weekFolders{end}));
    legend('Average Cell Voltage - Online', 'Average Cell Voltage - total', 'Location', 'best');
    grid on;

end
