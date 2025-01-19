%% 1. 기본 설정 및 날짜 폴더 자동 검출
clc; clear; close all

baseDir    = 'G:\공유 드라이브\BSL_Data2\한전_김제ESS';
kimjFolder = '202106_KIMJ';
basePath   = fullfile(baseDir, kimjFolder);

% 폴더 내의 모든 폴더 목록 가져오기
allItems = dir(basePath);
folderNames = {allItems([allItems.isdir]).name};
% '.' 와 '..' 제거
folderNames = folderNames(~ismember(folderNames, {'.', '..'}));

% 날짜 형식의 폴더만 선택 (예: '20210601'은 8자리 숫자)
isDateFolder = cellfun(@(x) ~isempty(regexp(x, '^\d{8}$', 'once')), folderNames);
dateFolders = folderNames(isDateFolder);

% 날짜 폴더들을 오름차순으로 정렬 (문자열이지만 YYYYMMDD 형식이면 올바르게 정렬됨)
dateFolders = sort(dateFolders);

%% 2. 원하는 주간 기간 선택 (예: 20210601 ~ 20210607)
weekStart = '20210601';
weekEnd   = '20210630';

% 문자열을 숫자로 변환하여 범위 비교 수행
weekFolders = dateFolders(cellfun(@(x) (str2double(x) >= str2double(weekStart)) && ...
                                       (str2double(x) <= str2double(weekEnd)), dateFolders));
                                   
fprintf('선택된 주간 폴더:\n');
disp(weekFolders);


% RBMS 파일의 파일명 패턴 (여기서는 날짜와 관련된 부분은 각 날짜 폴더 내에 있으므로, 파일명은 예를 들어 '20210602_LGCHEM_RBMS*.csv' 형태)
filePatternTemplate = '%s_LGCHEM_RBMS*.csv';

% 헤더 관련: 날짜별 파일에서는 11번째 줄이 변수명이 있는 것으로 가정
n_hd = 11;

%% 2. 여러 날짜 폴더에 걸쳐 모든 파일을 읽어서 그룹별로 분류
% containers.Map을 이용해 그룹별 파일의 전체 경로(cell array)를 저장
groupFiles = containers.Map();

for i = 1:length(weekFolders)
    currDate = weekFolders{i};
    data_folder = fullfile(baseDir, kimjFolder, currDate);
    
    % 파일 패턴 (날짜 부분은 해당 폴더에 맞게 조정)
    filePattern = fullfile(data_folder, sprintf(filePatternTemplate, currDate));
    fileList = dir(filePattern);
    
    % 각 파일에 대해 그룹화 (정규표현식 이용)
    for j = 1:length(fileList)
        fname = fileList(j).name;
        fullPath = fullfile(fileList(j).folder, fname);
        % 정규표현식: 날짜와 상관없이 RBMS 그룹 부분만 추출
        % 예: '20210602_LGCHEM_RBMS[01]_1.csv' 또는 '20210602_LGCHEM_RBMS[01].csv'에서
        % '20210602_LGCHEM_RBMS[01]'를 추출합니다.
        % 만약 날짜 부분을 통일할 필요가 있으면, RBMS 이후부터 추출하는 방법도 고려할 수 있습니다.
        expression = '(202106\d+_LGCHEM_RBMS\[\d+\])(?:_.*)?';
        tokens = regexp(fname, expression, 'tokens');
        if ~isempty(tokens)
            baseName = tokens{1}{1};  % 예: '20210602_LGCHEM_RBMS[01]'
            % 날짜가 포함되어 있으므로, 동일 그룹끼리 결합하려면 날짜 부분를 제거하거나 통일해야 합니다.
            % 예를 들어, '20210602_LGCHEM_RBMS[01]'와 '20210603_LGCHEM_RBMS[01]'를 같은 그룹으로 처리하고 싶다면,
            % 날짜 부분(20210602,20210603)을 제거하여 'LGCHEM_RBMS[01]'로 수정합니다.
            % 아래에서는 정규표현식으로 날짜 부분을 제거한 후 그룹명으로 사용합니다.
            grpName = regexprep(baseName, '^202106\d+_', '');  % 결과: 'LGCHEM_RBMS[01]'
            
            if isKey(groupFiles, grpName)
                temp = groupFiles(grpName);
                temp{end+1} = fullPath;
                groupFiles(grpName) = temp;
            else
                groupFiles(grpName) = {fullPath};
            end
        end
    end
end

%% 3. 각 그룹별 파일을 읽어서 하나의 테이블로 결합 및 플롯 생성
groupNames = keys(groupFiles);

for g = 1:length(groupNames)
    grpName = groupNames{g};  % 예: 'LGCHEM_RBMS[01]'
    filePaths = groupFiles(grpName);
    
    % 그룹별 데이터를 담을 빈 테이블 변수
    T_group = table();
    
    % 여러 파일(여러 날짜에 해당하는)을 순회하며 읽기
    for j = 1:length(filePaths)
        T_temp = readtable(filePaths{j}, 'FileType', 'text', ...
            'NumHeaderLines', n_hd, ...       % n_hd번째 줄이 변수명(헤더)
            'ReadVariableNames', true, ...
            'PreserveVariableNames', true);
        
        % 수직 결합 (같은 변수명이 동일한 구조로 있다고 가정)
        if isempty(T_group)
            T_group = T_temp;
        else
            T_group = [T_group; T_temp];  %#ok<AGROW>
        end
    end
    
    %% 4. 그룹별 데이터 플롯 생성
    % 예제에서는 "Sum. C.V.(V)"를 플롯하였으나, 원하는 다른 변수도 가능함.
%% (이전 코드의 그룹별 데이터 결합 후)
% 예: T_group는 현재 그룹에 해당하는 결합 테이블, grpName은 그룹명, weekFolders는 주간 폴더 목록

% Plot 1: Time vs Sum. C.V.(V)
figure;
plot(T_group.Time, T_group.('Sum. C.V.(V)'));
xlabel('Time');
ylabel('Sum. C.V.(V)');
title(sprintf('Time vs Sum. C.V.(V) for Group %s\n(%s ~ %s)', ...
      grpName, weekFolders{1}, weekFolders{end}));
grid on;

% Plot 2: Time vs SOC(%)
figure;
plot(T_group.Time, T_group.('SOC(%)'));
xlabel('Time');
ylabel('SOC (%)');
title(sprintf('Time vs SOC for Group %s\n(%s ~ %s)', ...
      grpName, weekFolders{1}, weekFolders{end}));
grid on;

% Plot 3: Time vs DC Current(A)
figure;
plot(T_group.Time, T_group.('DC Current(A)'));
xlabel('Time');
ylabel('DC Current (A)');
title(sprintf('Time vs DC Current for Group %s\n(%s ~ %s)', ...
      grpName, weekFolders{1}, weekFolders{end}));
grid on;

% Plot 4: Time vs Average C.V.(V)
figure;
plot(T_group.Time, T_group.('Average C.V.(V)'));
xlabel('Time');
ylabel('Average C.V.(V)');
title(sprintf('Time vs Average C.V.(V) for Group %s\n(%s ~ %s)', ...
      grpName, weekFolders{1}, weekFolders{end}));
grid on;

% Plot 5: Time vs Average M.T.(oC)
figure;
plot(T_group.Time, T_group.('Average M.T.(oC)'));
xlabel('Time');
ylabel('Average M.T.(oC)');
title(sprintf('Time vs Average M.T.(oC) for Group %s\n(%s ~ %s)', ...
      grpName, weekFolders{1}, weekFolders{end}));
grid on;


end