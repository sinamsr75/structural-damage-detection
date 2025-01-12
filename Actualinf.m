 clc
 clear all
 close all

Name = 'Moment Frame1.xlsx';

    % Damage Senario 1.
    Alpha = [0	0	0	0	0	0	0	0.05	0	0	0	0	0	0	0.08	0	0	0	0	0	0	0	0	0.1	0	0	0	0]; % Damage scenario
    save Alpha.mat Alpha
    
    Nodal_Data = xlsread(Name,1);                                           
    Element_Data = xlsread(Name,2);                                        

    NNode = size(Nodal_Data,1);
    NElement = size(Element_Data,1);

    Coordinate = Nodal_Data(:,2 : 3);

    DOF = 3 * NNode;

    Restrained_Vector = zeros(DOF,1);
    for i = 1 : NNode
        Restrained_Vector(3 * i - 2) = Nodal_Data(i,4);
        Restrained_Vector(3 * i - 1) = Nodal_Data(i,5);
        Restrained_Vector(3 * i - 0) = Nodal_Data(i,6);
    end

    Connectivity = Element_Data(:,2 : 3);

    Material_Property = Element_Data(:,4 : 6);

    Element_Type = Element_Data(:,7);

    Element_Geometry = zeros(NElement,3);
    for i = 1 : NElement
        
        Node_1 = Connectivity(i,1);
        Node_2 = Connectivity(i,2);

        X1 = Coordinate(Node_1,1);
        X2 = Coordinate(Node_2,1);
        Y1 = Coordinate(Node_1,2);
        Y2 = Coordinate(Node_2,2);

        L = sqrt(((X2 - X1) ^ 2) + ((Y2 - Y1) ^ 2));
        
        C = (X2 - X1) / L;
        S = (Y2 - Y1) / L;

        Element_Geometry(i,1) = L;
        Element_Geometry(i,2) = C;
        Element_Geometry(i,3) = S;
    end
    
    %% Calculation of the Stiffness Matrices.

    K_Element = zeros(6,6,NElement);
    for i = 1 : NElement
        E = (1-Alpha(i)) * Material_Property(i,1);
        A = Material_Property(i,2);
        MI = Material_Property(i,3);
        L = Element_Geometry(i,1);
        C = Element_Geometry(i,2);
        S = Element_Geometry(i,3);
        
        if  Element_Type(i) == 1
            T = [C,S,0,0,0,0;
                 -S,C,0,0,0,0;
                 0,0,1,0,0,0;
                 0,0,0,C,S,0;
                 0,0,0,-S,C,0;
                 0,0,0,0,0,1];
    
            C1 = (A * E) / L;
            C2 = (E * MI) / (L ^ 3);
            KK = [C1  ,0       ,0        ,-C1       ,0         ,0;
                  0   ,12*C2   ,6*C2*L   ,0         ,-12*C2    ,6*C2*L;
                  0   ,6*C2*L  ,4*C2*L*L ,0         ,-6*C2*L   ,2*C2*L*L;
                  -C1 ,0       ,0        ,C1        ,0         ,0;
                  0   ,-12*C2  ,-6*C2*L  ,0         ,12*C2     ,-6*C2*L;
                  0   ,6*C2*L  ,2*C2*L*L ,0         ,-6*C2*L   ,4*C2*L*L];
    
            K_Element(:,:,i) = T' * KK * T;
        end
        if  Element_Type(i) == 2
            T = [C,S,0,0;
                -S,C,0,0;
                 0,0,C,S;
                 0,0,-S,C];
            
            C1 = (A * E) / L;
            KK = [C1,0,-C1,0;
                 0,0,0,0;
                -C1,0,C1,0;
                 0,0,0,0];

    
            Local_KK = T' * KK * T;
            Final_K = zeros(6,6);
            Final_K(1:2,1:2) = Local_KK(1:2,1:2);
            Final_K(1:2,4:5) = Local_KK(1:2,2:3);
            Final_K(4:5,1:2) = Local_KK(2:3,1:2);
            Final_K(4:5,4:5) = Local_KK(2:3,2:3);
            K_Element(:,:,i) = Final_K;
        end
    end

    DOF = 3 * NNode;
    K = zeros(DOF,DOF);
    for i = 1 : NElement
        Node_1 = Connectivity(i,1);
        Node_2 = Connectivity(i,2);

        Rows = [3 * Node_1 - 2,3 * Node_1 - 1,3 * Node_1 - 0,3 * Node_2 - 2,3 * Node_2 - 1,3 * Node_2 - 0];
        Columns = [3 * Node_1 - 2,3 * Node_1 - 1,3 * Node_1 - 0,3 * Node_2 - 2,3 * Node_2 - 1,3 * Node_2 - 0];
        
        for ii = 1 : 6
            R = Rows(ii);
            for jj = 1 : 6
                C = Columns(jj);
                K(R,C) = K(R,C) + K_Element(ii,jj,i);
            end
        end
    end
    
    
    % Employement of the Boundary Conditions.
    
    DOF = 3 * NNode;
    K_Condensed = K;
    for i = 1 : DOF
        I = DOF - i + 1;
        if  Restrained_Vector(I) == 1
            K_Condensed(I,:) = [];
            K_Condensed(:,I) = [];
        end
    end
    
%     %% Stiffness Matrix Condensation.
    
    [r,c] = size(K_Condensed);   
    

    lx = 1:3:r;
    ly = lx +1;
    lz = lx + 2;
    new_K = zeros(r, c);
    n = r / 3;

    new_K(1:n, :) = K_Condensed(lx, :);
    new_K(n+1:2*n, :) = K_Condensed(ly, :);
    new_K(2*n +1:3*n, :) = K_Condensed(lz, :);
    
    K_M(:, 1:n) = new_K(:, lx);
    K_M(:, n+1:2*n) = new_K(:, ly);
    K_M(:, 2*n +1:3*n) = new_K(:, lz);
    
    K_ee = zeros(n);
    K_ee(1:n, :) =  K_M(1:n, 1:n);
    K_ei = zeros(n);                                                        %#ok!
    K_ei = K_M(1:n, n+1:3*n);                                               
    K_ie = zeros(n);                                                        %#ok!
    K_ie = K_M(n+1:3*n, 1:n);                                              
    K_ii = zeros(n);                                                        %#ok!                                                    
    K_ii = K_M(n+1:3*n, n+1:3*n);
    KC = K_ee - K_ei * inv(K_ii) * K_ie;                                    %#ok!
    
    %% Calculation of the Mass Matrices.
    
    M_Element = zeros(6,6,NElement);
    for i = 1 : NElement
        
        A = Material_Property(i,2);
        L = Element_Geometry(i,1);
        C = Element_Geometry(i,2);
        S = Element_Geometry(i,3);
        T = [C,S,0,0,0,0;
            -S,C,0,0,0,0;
             0,0,1,0,0,0;
             0,0,0,C,S,0;
             0,0,0,-S,C,0;
             0,0,0,0,0,1];
        
        
        if  Element_Type(i) == 1

            Rho = 7850;

            L2=L*L; MM=Rho*A*L/420*...
            [140 0 0 70 0 0 ;
            0 156 22*L 0 54 -13*L;
            0 22*L 4*L2 0 13*L -3*L2;
            70 0 0 140 0 0 ;
            0 54 13*L 0 156 -22*L ;
            0 -13*L -3*L2 0 -22*L 4*L2 ];

            M_Element(:,:,i) =  T.' * MM * T;
        end
        if  Element_Type(i) == 2
            
            T = [C,S,0,0;-S,C,0,0;0,0,C,S;0,0,-S,C];
            Me = 7850 * A * L /6;
            MM = Me * [2,0,1,0;0,2,0,1;1,0,2,0;0,1,0,2];

    
            Local_MM = T' * MM * T;

            Final_M = zeros(6,6);
            Final_M(1:2,1:2) = Local_MM(1:2,1:2);
            Final_M(1:2,4:5) = Local_MM(1:2,2:3);
            Final_M(4:5,1:2) = Local_MM(2:3,1:2);
            Final_M(4:5,4:5) = Local_MM(2:3,2:3);
            M_Element(:,:,i) = Final_M;
        end
    end

    DOF = 3 * NNode;
    M = zeros(DOF,DOF);
    for i = 1 : NElement
        
        Node_1 = Connectivity(i,1);
        Node_2 = Connectivity(i,2);

        Rows = [3 * Node_1 - 2,3 * Node_1 - 1,3 * Node_1 - 0,3 * Node_2 - 2,3 * Node_2 - 1,3 * Node_2 - 0];
        Columns = [3 * Node_1 - 2,3 * Node_1 - 1,3 * Node_1 - 0,3 * Node_2 - 2,3 * Node_2 - 1,3 * Node_2 - 0];
        
        for ii = 1 : 6
            R = Rows(ii);
            for jj = 1 : 6
                C = Columns(jj);
                M(R,C) = M(R,C) + M_Element(ii,jj,i);
            end
        end
    end
    
     % Employement of the Boundary Conditions.

       DOF = 3 * NNode;
       M_Condensed = M;
       for i = 1 : DOF
         I = DOF - i + 1;
         if  Restrained_Vector(I) == 1
             M_Condensed(I,:) = [];
              M_Condensed(:,I) = [];
         end
       end
       
       
    %% Mass Matrix Condensation.
          
    [r, c] = size(M_Condensed);

    lx = 1:3:r;
    ly = lx +1;
    lz = lx + 2;
    n = r / 3;

    new_M = zeros(r, c);

    new_M(1:n, :) = M_Condensed(lx, :);
    new_M(n+1:2*n, :) = M_Condensed(ly, :);
    new_M(2*n+1:3*n, :) = M_Condensed(lz, :);
    
    M_M(:, 1:n) = new_M(:, lx);
    M_M(:, n+1:2*n) = new_M(:, ly);
    M_M(:, 2*n +1:3*n) = new_M(:, lz);
    
    M_ee = zeros(n);
    M_ee(1:n, :) =  M_M(1:n, 1:n);
    MC = M_ee;
    
    %% Solve for the natural frequencies and modes
    [V, D] = eig(K_Condensed, M_Condensed);
    Omega = sqrt(diag(D));
    Frequencies = Omega/(2*pi);
    Modes_shape = V;
   
    [a,b] = size(Modes_shape);                                                      
    for i = 1 : a
    Modes_shape(:,i) = Modes_shape(:,i)/(max(abs(Modes_shape(:,i))));
    end  

	save Modes_shape.mat Modes_shape
    save Frequencies.mat Frequencies
    
    
	%% Plot the Initial Configurations.
    F1 = figure('Name','Structures','NumberTitle','off','Units','normalized','OuterPosition',[0,0,1,1]); 
    hold on
    for i = 1 : NElement
        % Detection of the Nodes of each Element.
        Node_1 = Connectivity(i,1);
        Node_2 = Connectivity(i,2);

        % Detection of the Element Nodal Coordinates.
        X1 = Coordinate(Node_1,1);
        X2 = Coordinate(Node_2,1);
        Y1 = Coordinate(Node_1,2);
        Y2 = Coordinate(Node_2,2);

        % Creation of the Plot Variables (Initial Structure).
        XP = [X1,X2];
        YP = [Y1,Y2]; 

        % Plot the Initial Structure.
        PI = plot(XP,YP,'Color','b','LineStyle','-','LineWidth',3,'Marker','o','MarkerSize',6,'MarkerFaceColor','g','MarkerEdgeColor','g');
    end
    
	% Edit the Figure Outputs.
	FP_X = 0.9;
    FP_Y = 0.025; 
    hold off
    grid on
    xlabel('X Coordinate','FontWeight','bold','FontSize',13);
    ylabel('Y Coordinate','FontWeight','bold','FontSize',13);
    title('Sample Structures','FontWeight','bold','FontSize',15)
    XP = Coordinate(:,1);
    YP = Coordinate(:,2);
    LX = max(XP) - min(XP);
    LY = max(YP) - min(YP);
    xlim([min(XP) - (FP_X * LX),max(XP) + (FP_X * LX)]);
    ylim([min(YP) - (FP_Y * LY),max(YP) + (FP_Y * LY)]);
    save('StructuralData.mat','Nodal_Data','Element_Data','Coordinate','DOF','Restrained_Vector','Connectivity','Material_Property','Element_Type')