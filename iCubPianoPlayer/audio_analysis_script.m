
% 
% tone_onset_times=[0 0];
% 
% tone_offset_times=0;
% 
% while length(tone_onset_times)~=length(tone_offset_times)
% 

    %%%%% w = FFT time window size

    sampling_freq=22050;
    recObj = audiorecorder(sampling_freq, 16, 1);

    pause(4)
    disp('Start speaking.')
    recordblocking(recObj, 30);
    disp('End of Recording.');

    %%
    % play(recObj);



    recording = getaudiodata(recObj);

    figure(1)
    plot(recording)

    %%
    
    time_window_size = 1000;
    
   total_time_windows=fix((length(recording)-time_window_size)/time_window_size);

    for time_step_number=1:total_time_windows

        time_start = 1+(time_step_number-1)*time_window_size;
        time_end = time_start+time_window_size;

        spectrogram(time_step_number,:) = fft(recording(time_start:time_end));

    end

    spectrogram_cropped=spectrogram(:,1:200);

% 
    figure(2)
    imagesc(abs(spectrogram))

    figure(3)
    imagesc(abs(spectrogram_cropped))

    %%
    
    amplitude_threshold=20;

    [max_amplitude,freq]=max(spectrogram_cropped,[],2);
    freq=freq*5.3;
    max_amplitude_abs=abs(max_amplitude);
    max_amplitude_abs=smooth(max_amplitude_abs);
   
    tone_presence=zeros(size(freq));
    tone_presence(find(max_amplitude_abs>amplitude_threshold))=1;
    max_amplitude_abs_tones=max_amplitude_abs;
    max_amplitude_abs_tones(find(max_amplitude_abs_tones<amplitude_threshold))=0;


    tone_times=diff(tone_presence);
    
    tone_onset_time_bins=find(tone_times==1);
    tone_onset_times=tone_onset_time_bins*time_window_size/10;

     tone_offset_time_bins=find(tone_times==-1);
    tone_offset_times=tone_offset_time_bins*time_window_size/10;
% 
%     if length(tone_onset_times)~=length(tone_offset_times)
%         disp('PLEASE PRESS A KEY & REPEAT THE MELODY')
%         pause
%     end
%     
%     if isempty(tone_onset_times) && isempty(tone_offset_times)
%         disp('PLEASE PRESS A KEY & REPEAT THE MELODY')
%         pause
%     end
% 
% 
% end
   
%%
    
total_tones=length(tone_onset_times);


for tone_number=1:total_tones
    
    melody_frequencies(tone_number) =  median(freq(tone_onset_time_bins(tone_number):tone_offset_time_bins(tone_number)));
    while melody_frequencies(tone_number) < 392
        melody_frequencies(tone_number)=melody_frequencies(tone_number)*2;
    end
    
end

figure(4)
plot(freq)

figure(5)
plot(max_amplitude_abs)    
  
figure(6)
plot(max_amplitude_abs_tones)

figure(7)
plot(tone_presence)

figure(8)
plot(tone_presence.*freq)

%%
semitone_frequencies(1) = 392;

% semitone_factor = nthroot(2,12);
% semitone_factor = 1.06


for semitone = 2:12
    semitone_frequencies(semitone) = semitone_frequencies(semitone-1)*semitone_factor;
end

for tone_number=1:total_tones

    tmp = abs(semitone_frequencies-melody_frequencies(tone_number));
    [freq_diff,semitone_match] = min(tmp); %index of closest value

    melody_frequencies_tuned(tone_number) = semitone_frequencies(semitone_match);
    melody_notes(tone_number) = semitone_match;
    
    if melody_notes(tone_number) == 1
        melody_keys(tone_number) = 1;
        robot_arm(tone_number)=0;
        robot_joint(tone_number)=13; 
        
    elseif melody_notes(tone_number) == 3
        melody_keys(tone_number) = 2;
        robot_arm(tone_number)=0;
        robot_joint(tone_number)=11; 
        
    elseif melody_notes(tone_number) == 5
        melody_keys(tone_number) = 3;
        robot_arm(tone_number)=1;
        robot_joint(tone_number)=12; 
        
    elseif melody_notes(tone_number) == 6
        melody_keys(tone_number) = 4; 
        robot_arm(tone_number)=1;
        robot_joint(tone_number)=14; 
    end
        
  
end



semitone_struc.semitone(1).name = 'G';
semitone_struc.semitone(2).name = 'G#';
semitone_struc.semitone(3).name = 'A';
semitone_struc.semitone(4).name = 'A#';
semitone_struc.semitone(5).name = 'B';
semitone_struc.semitone(6).name = 'C';
semitone_struc.semitone(7).name = 'C#';
semitone_struc.semitone(8).name = 'D';
semitone_struc.semitone(9).name = 'D#';
semitone_struc.semitone(10).name = 'E';
semitone_struc.semitone(11).name = 'F';
semitone_struc.semitone(12).name = 'F#';


for tone_number=1:total_tones

    disp(semitone_struc.semitone(melody_notes(tone_number)).name);
    
end


%% 

%%
%%%%%% Produce pure tones to replicated heard melody
% 
% for tone_number=1:total_tones
% 
%     disp(semitone_struc.semitone(melody_notes(tone_number)).name);
%     
% end
% 
% 
% fs = 8000;
% 
%         T = 3; % 2 seconds duration
%         t = 0:(1/fs):T;
%  f = 440;
%        a = 0.5;
%        y = a*sin(2*pi*f*t);
%        
%        
%        
%        sound(y, fs);