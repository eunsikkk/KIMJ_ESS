%% 1. 기본 설정 및 날짜 폴더 자동 검출
clc; clear; close all

baseDir    = 'G:\공유 드라이브\BSL_Data2\한전_김제ESS';
kimjFolder = '202106_KIMJ';
basePath   = fullfile(baseDir, kimjFolder);

% 폴더 내의 모든 폴더 목록 가져오기
allItems = dir(basePath);
folderNames = {allItems([allItems.isdir]).name};


% 날짜 폴더들을 오름차순으로 정렬 
dateFolders = sort(folderNames);

%% 2. 원하는 주간 기간 선택
weekStart = '20210615';
weekEnd   = '20210615';

% 문자열을 숫자로 변환
weekFolders = dateFolders(cellfun(@(x) (str2double(x) >= str2double(weekStart)) && ...
                                       (str2double(x) <= str2double(weekEnd)), dateFolders));
                                   
fprintf('선택된 주간 폴더:\n');
disp(weekFolders);

% RBMS 파일의 파일명 패턴
filePatternTemplate = '%s_LGCHEM_RBMS*.csv';

% 헤더 
n_hd = 11;

%% 3. 여러 날짜 폴더에 걸쳐 모든 파일을 읽어서 그룹별로 분류
% containers.Map을 이용해 그룹별 파일의 전체 경로(cell array)를 저장
groupFiles = containers.Map();

for i = 1:length(weekFolders)
    currDate = weekFolders{i};
    data_folder = fullfile(baseDir, kimjFolder, currDate);
    
    % 파일 패턴 
    filePattern = fullfile(data_folder, sprintf(filePatternTemplate, currDate));
    fileList = dir(filePattern);
    
    % 각 파일에 대해 그룹화
    for j = 1:length(fileList)
        fname = fileList(j).name;
        fullPath = fullfile(fileList(j).folder, fname);

        expression = '(202106\d+_LGCHEM_RBMS\[\d+\])(?:_.*)?';
        tokens = regexp(fname, expression, 'tokens');
        if ~isempty(tokens)
            baseName = tokens{1}{1};  % 예: '20210602_LGCHEM_RBMS[01]'
            % 날짜가 포함되어 있으므로 동일 그룹끼리 결합하려면 날짜 부분 제거
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

%% 4. 그룹별 파일을 읽어서 하나의 테이블로 결합 및 플롯 생성

groupNames = sort(keys(groupFiles));

rackInput = input('플롯할 랙 번호를 입력하세요 (예: 1 ~ 8): ');
% 랙 번호를 두 자리 문자열로 변환 
rackStr = sprintf('%02d', rackInput);
% 선택된 그룹명 구성 (예: 'LGCHEM_RBMS[01]')
selectedGroup = sprintf('LGCHEM_RBMS[%s]', rackStr);

fprintf('선택된 랙: %s\n', selectedGroup);

% 선택된 그룹의 파일 경로들을 가져옴
filePaths = groupFiles(selectedGroup);

% 선택된 그룹의 데이터를 담을 빈 테이블 변수
T_group = table();

% 여러 파일(여러 날짜에 해당하는)을 순회하며 읽기
for j = 1:length(filePaths)
    T_temp = readtable(filePaths{j}, 'FileType', 'text', ...
        'NumHeaderLines', n_hd, ...       % n_hd번째 줄이 변수명(헤더)
        'ReadVariableNames', true, ...
        'PreserveVariableNames', true);
    
    % 수직 결합 (같은 변수명을 가진 구조로 가정)
    if isempty(T_group)
        T_group = T_temp;
    else
        T_group = [T_group; T_temp];  %#ok<AGROW>
    end
end

%% 5. 선택된 랙 데이터 플롯 생성


% Plot 1: Time vs Sum. C.V.(V)
figure;
plot(T_group.Time, T_group.('Sum. C.V.(V)'));
xlabel('Time');
ylabel('Sum. C.V.(V)');
title(sprintf('Time vs Sum. C.V.(V) for %s\n(%s ~ %s)', ...
      selectedGroup, weekFolders{1}, weekFolders{end}));
grid on;

% Plot 2: Time vs SOC(%)
figure;
plot(T_group.Time, T_group.('SOC(%)'));
xlabel('Time');
ylabel('SOC (%)');
title(sprintf('Time vs SOC for %s\n(%s ~ %s)', ...
      selectedGroup, weekFolders{1}, weekFolders{end}));
grid on;

% Plot 3: Time vs DC Current(A)
figure;
plot(T_group.Time, T_group.('DC Current(A)'));
xlabel('Time');
ylabel('DC Current (A)');
title(sprintf('Time vs DC Current for %s\n(%s ~ %s)', ...
      selectedGroup, weekFolders{1}, weekFolders{end}));
grid on;

% Plot 4: Time vs Average C.V.(V)
figure;
plot(T_group.Time, T_group.('Average C.V.(V)'));
xlabel('Time');
ylabel('Average C.V.(V)');
title(sprintf('Time vs Average C.V.(V) for %s\n(%s ~ %s)', ...
      selectedGroup, weekFolders{1}, weekFolders{end}));
grid on;

% Plot 5: Time vs Average M.T.(oC)
figure;
plot(T_group.Time, T_group.('Average M.T.(oC)'));
xlabel('Time');
ylabel('Average M.T.(oC)');
title(sprintf('Time vs Average M.T.(oC) for %s\n(%s ~ %s)', ...
      selectedGroup, weekFolders{1}, weekFolders{end}));
grid on;
