/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServiceElectricPlant]    Script Date: 09/05/2023 23:28:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =========================================================================================================================================================================
-- Description: Function for Businees Rules "AdditionalServiceElectricPlant"
-- Change History:
--	2019-07-15	Amilkar Martínez: Created Function
--	2019-09-04	Amilkar Martínez / Alexander Zapata: Se agrega el tipo de criterio modo para saber la forma en que calcula los tiempos de las plantas adicionales
--													 @CalculatedTimeMode 1 = se calculan los tiempos sin importar las etapas
--													 @CalculatedTimeMode 2 = se calculan los tiempos para (ultimo vuelo + limpieza terminal) y por aparte (primer vuelo)
--	2020-03-26	Amilkar Martínez: a partir del 01 febrero 2020 las plantas matenimiento de viva se trabajan como adicionales desde el primer minuto en fracciones de 1 hora
--	2020-09-14	Sebastián Jaramillo: Configuración otro Sí Viva Colombia Covid se quita bolsa de plantas para Rampa se incluye en adicionales
--  2021-02-12	Sebastián Jaramillo: Segregación Plantas Pernocta MTO en Avianca / Avianca y Regional / Avianca
--	2021-02-15	Sebastián Jaramillo: Se incluye RN Planta LATAM Contrato Nuevo PSO
--	2021-02-16	Sebastián Jaramillo: Se adiciona la columna centro de costos en la tabla retornada
--	2021-06-30	Sebastián Jaramillo: Se incluye RN Planta LATAM Contrato Nuevo AXM
--	2021-07-21	Sebastián Jaramillo: Se cambia RN de Regional Express
--	2021-08-31	Sebastián Jaramillo: Se incluye RN de VivaAerobus
--	2021-11-01	Sebastián Jaramillo: Se incluye RN Planta LATAM Contrato Nuevo EYP
--	2021-11-03	Sebastián Jaramillo: Se incluye RN Contrato Nuevo SARPA
--	2021-11-10	Sebastián Jaramillo: Se incluye RN Atención AVA - SAI en BOG
--	2020-09-14	Sebastián Jaramillo: Ajuste en RN VivaColombia
--	2021-12-06	Sebastián Jaramillo: Nueva RN American Airlines	
--	2022-01-31	Sebastián Jaramillo: Nueva RN Ultra Air
--	2022-03-11	Sebastián Jaramillo: Conciliación RN LATAM Plantas CTG y ordenamiento de la lógica de los IF de manera mas administrable.
--	2022-04-29	Sebastián Jaramillo: Se ajusta RN VivaAerobus incluyendo MDE como un nuevo aeropuerto
--	2022-07-28	Sebastián Jaramillo: Se ajusta RN VivaColombia para indicar explícitamente servicios internacionales
--	2022-09-28	Sebastián Jaramillo: Se adicionan RN Arajet
--	2022-11-11	Sebastián Jaramillo: Se incluye RN para el cliente Aerolineas Argentinas
--	2023-02-13	Sebastián Jaramillo: Se configura nuevo contrato de Avianca 2023 "TAKE OFF 20230201" y Regional Express se integra como un "facturar a" más de Avianca
--	2023-03-30	Sebastián Jaramillo: Se configura RN LATAM RCH / Configuración RN LANCO ADZ
--	2023-04-20	Sebastián Jaramillo: Fusión TALMA-SAI BOGEX Incorporación RN AVA estaciones (BGA, MTR, PSO, IBE, NVA) Compañía: Avianca - Facturar a: SAI
--	2023-05-09	Diomer Bedoya	   : Se incluye RN TALMA-SAI SPIRIT  Compañía: SPIRIT - Facturar a: SAI

-- =========================================================================================================================================================================
--SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServiceElectricPlant] (20565,11,13,'E190','115VAC',9,9,null,48,'2019-09-01')
--
ALTER FUNCTION [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServiceElectricPlant]
(                               
    @ServiceHeaderId BIGINT,	
	@AirportId INT,
	@StageTypeId INT, --OJO SE RECIBE COMO PARÁMETRO LA ETAPA DEL SERVICIO
	@AircraftTypeCode NVARCHAR(50),  
	@GroupTypeEnergy  NVARCHAR(50),
	@CompanyId INT,
	@BillingToCompany INT,		
	@OriginId INT,
	@DestinationId INT,	
	@DateService DATE
)
RETURNS @T_Result TABLE(ROW INT IDENTITY, StartDate DATETIME, EndDate DATETIME, [Time] INT, AdditionalService BIT, AdditionalStartHour DATETIME, 
                        AdditionalEndHour DATETIME, AdditionalTime INT, AdditionalQuanty INT, AdditionalServiceName VARCHAR(150), Fraction VARCHAR(25), TimeLeftover INT, CostCenter NVARCHAR(50))				
AS
BEGIN
	--DECLARE @ServiceHeaderId BIGINT = 1557
	--DECLARE @AirportId INT = 1
	--DECLARE @StageTypeId INT = 4 
	--DECLARE @AircraftTypeCode NVARCHAR(50) = '7'
	--DECLARE @GroupTypeEnergy  NVARCHAR(50) = NULL
	--DECLARE @CompanyId INT = 43
	--DECLARE @BillingToCompany INT = 1	
	--DECLARE @OriginId INT = 75
	--DECLARE @DestinationId INT = NULL
	--DECLARE @DateService DATE = '2019-09-05'
	--======================================

	DECLARE @BusinessRuleGroupId INT = 7
	DECLARE @HeaderRuleId INT
	DECLARE	@CriteriaId INT
	DECLARE	@VariableId INT
	DECLARE	@Value INT
	DECLARE	@Comply BIT
	DECLARE @FractionResult VARCHAR(25)
	DECLARE @MinutesResult INT
	DECLARE @CalculatedTimeMode TINYINT = 1 --Calcular tiempos juntos de plantas en la pernocta (ultimo vuelo + limpieza + primer vuelo)

	DECLARE	@ExtraText VARCHAR(50) = ''

	DECLARE @TimeLeftover FLOAT=0 -- Tiempo Restante
	DECLARE @ServiceDetail AS [CIOReglaNegocio].[ServiceDetailType]--TIPO DEFINIDO
	DECLARE @ServiceDetailFiltered AS CIOReglaNegocio.ServiceDetailType--TIPO DEFINIDO
	
	--CONSULTA PRINCIPAL   
	INSERT	@ServiceDetail
	SELECT	ROW_NUMBER() OVER(ORDER BY DS.DetalleServicioId) [Row],
			'PLANTA ELECTRICA ' + ISNULL(@GroupTypeEnergy, '#Tipo de Avión sin valor en @GroupTypeEnergy#' + @AircraftTypeCode) [ServiceName],
			--'PLANTA ELECTRICA ADICIONAL',
			DS.FechaInicio, 
			DS.FechaFin, 
			DATEDIFF(MI, DS.FechaInicio, DS.FechaFin) TotalTime, 
			DS.Cantidad
	FROM	CIOServicios.DetalleServicio DS
	WHERE	     DS.Activo = 1 	       
			AND  DS.TipoActividadId = 3 /* Planta Eléctrica */
			AND  DS.EncabezadoServicioId = @ServiceHeaderId
			AND  NOT (@CompanyId = 9 and ISNULL(DS.PropietarioId, 0) = 5) --OJO SE ESCLUYEN LAS HORAS DE COPA CONECTADAS CON EQUIPO PROPIO DE ELLOS
	        AND  NOT (ISNULL(DS.PropietarioId, 0) = 2 AND @AirportId = 12) --SE ESCLUYEN LAS PLANTAS QUE SON DE MUELLE EN BOG

	DECLARE @ServiceGPUTime INT = (SELECT SUM(TiempoTotal) FROM @ServiceDetail)

	IF (SELECT SUM(TiempoTotal) FROM @ServiceDetail) = 0 AND @CompanyId NOT IN (9, 72) RETURN --SE TIENE ESTA LINEA PARA OPTIMIZAR EL RENDIMIENTO CON COPA / WINGO NO SE PUEDE POR EL CALCULO DEL TIEMPO DENDIENTE EN EL CASO DE LAS PERNOCTAS

	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	--SPIRIT / SAI
	IF (@CompanyId=195 AND @BillingToCompany=87)
	BEGIN
		IF (@DateService >= '2023-05-09')
		BEGIN
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 60.0, NULL,NULL)
			RETURN
		END
	END
	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	--AEROLINEAS ARGENTINAS / AEROLINEAS ARGENTINAS
	IF (@CompanyId=67 AND @BillingToCompany=67)
	BEGIN
		IF (@DateService >= '2022-11-01')
		BEGIN
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 60.0, NULL,NULL)
			RETURN
		END
	END

	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	--ARAJET / ARAJET
	IF (@CompanyId=272 AND @BillingToCompany=272)
	BEGIN
		IF (@DateService >= '2022-09-15')
		BEGIN
			IF (@AirportId = 12) --BOG (NO TIENE INCLUIDA PLANTA)
			BEGIN
				INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL,NULL)
				RETURN
			END
			
			-- LAS DEMÁS ESTACIONES TIENEN 45 MINUTOS INCLUIDOS
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 45, 30.0, NULL,NULL)
			RETURN
		END
	END

	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	--ULTRA AIR / ULTRA AIR
	IF (@CompanyId=259 AND @BillingToCompany=259)
	BEGIN
		IF (@DateService >= '2022-01-20')
		BEGIN
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 40, 30.0, NULL,NULL)

			RETURN
		END
	END

	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	--AMERICAN AIRLINES / AMERICAN AIRLINES
	IF (@CompanyId=43 AND @BillingToCompany=43)
	BEGIN
		IF (@DateService >= '2021-12-04')
		BEGIN
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0,NULL,NULL)

			RETURN
		END
	END

	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	 --AVIANCA A SAI
	IF (@CompanyId = 1 AND @BillingToCompany = 87)
	BEGIN
		 --INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL, @ServiceHeaderId)
		 --RETURN
		IF (@DateService >= '2023-04-19' AND @AirportId IN (11, 40, 47, 31, 43)) --BGA, MTR, PSO, IBE, NVA
		BEGIN
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 70, 15.0, NULL, NULL) --TTO 
			IF (@StageTypeId IN (2,3))
			BEGIN
				INSERT  @T_Result
				SELECT  StartDate
					,   EndDate
					,   Time
					,   AdditionalService
					,   AdditionalStartTime
					,   AdditionalEndTime
					,   AdditionalTime
					,   AdditionalQuanty
					,   AdditionalServiceName + ' MTO' AdditionalServiceName
					,   FractionName
					,   TimeLeftover
					,	'MTO' CostCenter
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 15.0, 2, @ServiceHeaderId) --PNTA
			END
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 15.0, 4, @ServiceHeaderId) --PVLO
			IF (@StageTypeId = 14) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO TTO
			IF (@StageTypeId = 5) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 70, 15.0, NULL,NULL) --ESCAL TEC LO MISMO QUE EL TTO VALIDADO CON DOÑA MONICA
			IF (@StageTypeId = 6) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --REG PLATAFORM
			IF (@StageTypeId = 15) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO PCTA

			RETURN
		END

		IF (@DateService >= '2021-10-27' AND @AirportId = 12) --BOG
		BEGIN
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL,NULL)
			RETURN
		END
	END

	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	--REGIONAL EXPRESS A AVIANCA (QUEDA OBSOLETA PORQUE YA NO SE USA MAS REGIONAL COMO COMPAÑÍA APARTE SE INTEGRA A AVIANCA VER MÁS ABAJO!!)
	IF (@CompanyId = 193 AND @BillingToCompany = 1)
	BEGIN
		IF (@DateService >= '2021-01-01') 
		BEGIN
			IF (@StageTypeId = 1)  INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 15.0,NULL,NULL) --TTO
			IF (@StageTypeId IN (2,3))
			BEGIN
				INSERT  @T_Result
				SELECT  StartDate
					,   EndDate
					,   Time
					,   AdditionalService
					,   AdditionalStartTime
					,   AdditionalEndTime
					,   AdditionalTime
					,   AdditionalQuanty
					,   AdditionalServiceName + ' MTO' AdditionalServiceName
					,   FractionName
					,   TimeLeftover
					,	'MTO' CostCenter
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 15.0, 2, @ServiceHeaderId) --PNTA
			END
			IF (@StageTypeId = 4) --PVLO
			BEGIN
				SELECT	@TimeLeftover = MIN(TimeLeftover)
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServiceElectricPlant](	
															@ServiceHeaderId,
															@AirportId,
															2,
															@AircraftTypeCode,
															@GroupTypeEnergy,
															@CompanyId,
															@BillingToCompany,
															NULL,
															NULL,
															@DateService)
					
				INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, @TimeLeftover, 15.0,4,@ServiceHeaderId)
			END
			IF (@StageTypeId NOT IN (1, 2, 3, 4)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0,NULL,NULL) --OTROS

			RETURN
		END

		-----------------------------------------------------------
		--OTRO SI NUEVA NEGOCIACION DESPUES 1 OLA COVID CON AVIANCA
		-----------------------------------------------------------
		IF (@DateService BETWEEN '2020-10-01' AND '2020-12-31') --REGIONAL EXPRESS AMERICAS SAS / AVIANCA S.A (POR CORREO DE CLAUDIA MORALES "Cambios Regional Express y socialización JAT CUC" se retira de este contrato)
		BEGIN
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 70, 15.0, NULL, NULL) --TTO 
			IF (@StageTypeId IN (2,3))
			BEGIN
				INSERT  @T_Result
				SELECT  StartDate
					,   EndDate
					,   Time
					,   AdditionalService
					,   AdditionalStartTime
					,   AdditionalEndTime
					,   AdditionalTime
					,   AdditionalQuanty
					,   AdditionalServiceName + ' MTO' AdditionalServiceName
					,   FractionName
					,   TimeLeftover
					,	'MTO' CostCenter
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 15.0, 2, @ServiceHeaderId) --PNTA
			END
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 15.0, 4, @ServiceHeaderId) --PVLO
			IF (@StageTypeId = 14) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO TTO
			IF (@StageTypeId = 5) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 70, 15.0, NULL,NULL) --ESCAL TEC LO MISMO QUE EL TTO VALIDADO CON DOÑA MONICA
			IF (@StageTypeId = 6) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --REG PLATAFORM
			IF (@StageTypeId = 15) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO PCTA

			RETURN
		END

		IF (@DateService <= '2020-09-30') 
		BEGIN
			IF (@StageTypeId = 1)  INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 15.0,NULL,NULL) --TTO
			IF (@StageTypeId IN (2,3))  INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 15.0,2,@ServiceHeaderId) --PNTA
			IF (@StageTypeId = 4) --PVLO
			BEGIN
				SELECT	@TimeLeftover = MIN(TimeLeftover)
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServiceElectricPlant](	
															@ServiceHeaderId,
															@AirportId,
															2,
															@AircraftTypeCode,
															@GroupTypeEnergy,
															@CompanyId,
															@BillingToCompany,
															NULL,
															NULL,
															@DateService)
					
				INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, @TimeLeftover, 15.0,4,@ServiceHeaderId)
			END
			IF (@StageTypeId NOT IN (1, 2, 3, 4)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0,NULL,NULL) --OTROS

			RETURN
		END
	END

	-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	--***************************************************************************************************************************************************************************************************************
	-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	--TODO EL COMPLEJO DE AVIANCA Y RELACIONADOS...

	---------------------------------------------------------------------------------------------
	--NUEVO CONTRATO TAKE OFF 20230201
	---------------------------------------------------------------------------------------------
	IF (@DateService >= '2023-02-01') 
	BEGIN
		IF (@CompanyId=1 AND @BillingToCompany=1) --AVIANCA S.A / AVIANCA S.A
		BEGIN
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 70, 15.0, NULL, NULL) --TTO 
			IF (@StageTypeId IN (2,3))
			BEGIN
				INSERT  @T_Result
				SELECT  StartDate
					,   EndDate
					,   Time
					,   AdditionalService
					,   AdditionalStartTime
					,   AdditionalEndTime
					,   AdditionalTime
					,   AdditionalQuanty
					,   AdditionalServiceName + ' MTO' AdditionalServiceName
					,   FractionName
					,   TimeLeftover
					,	'MTO' CostCenter
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 15.0, 2, @ServiceHeaderId) --PNTA
			END
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 15.0, 4, @ServiceHeaderId) --PVLO
			IF (@StageTypeId = 14) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO TTO
			IF (@StageTypeId = 5) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 70, 15.0, NULL,NULL) --ESCAL TEC LO MISMO QUE EL TTO VALIDADO CON DOÑA MONICA
			IF (@StageTypeId = 6) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --REG PLATAFORM
			IF (@StageTypeId = 15) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO PCTA

			RETURN
		END

		IF (@CompanyId=1 AND @BillingToCompany=193) --AVIANCA S.A / REGIONAL EXPRESS
		BEGIN
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 70, 15.0, NULL, NULL) --TTO 
			IF (@StageTypeId IN (2,3))
			BEGIN
				INSERT  @T_Result
				SELECT  StartDate
					,   EndDate
					,   Time
					,   AdditionalService
					,   AdditionalStartTime
					,   AdditionalEndTime
					,   AdditionalTime
					,   AdditionalQuanty
					,   AdditionalServiceName + ' MTO' AdditionalServiceName
					,   FractionName
					,   TimeLeftover
					,	'MTO' CostCenter
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 15.0, 2, @ServiceHeaderId) --PNTA
			END
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 15.0, 4, @ServiceHeaderId) --PVLO
			IF (@StageTypeId = 14) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO TTO
			IF (@StageTypeId = 5) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 70, 15.0, NULL,NULL) --ESCAL TEC LO MISMO QUE EL TTO VALIDADO CON DOÑA MONICA
			IF (@StageTypeId = 6) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --REG PLATAFORM
			IF (@StageTypeId = 15) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO PCTA

			RETURN
		END

		IF (@CompanyId=42 AND @BillingToCompany=1) --TACA / AVIANCA S.A
		BEGIN
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 70, 15.0, NULL, NULL) --TTO 
			IF (@StageTypeId IN (2,3))
			BEGIN
				INSERT  @T_Result
				SELECT  StartDate
					,   EndDate
					,   Time
					,   AdditionalService
					,   AdditionalStartTime
					,   AdditionalEndTime
					,   AdditionalTime
					,   AdditionalQuanty
					,   AdditionalServiceName + ' MTO' AdditionalServiceName
					,   FractionName
					,   TimeLeftover
					,	'MTO' CostCenter
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 15.0, 2, @ServiceHeaderId) --PNTA
			END
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 15.0, 4, @ServiceHeaderId) --PVLO
			IF (@StageTypeId = 14) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO TTO
			IF (@StageTypeId = 5) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 70, 15.0, NULL,NULL) --ESCAL TEC LO MISMO QUE EL TTO VALIDADO CON DOÑA MONICA
			IF (@StageTypeId = 6) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --REG PLATAFORM
			IF (@StageTypeId = 15) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO PCTA

			RETURN
		END

		IF (@CompanyId=47 AND @BillingToCompany=1) --AEROGAL / AVIANCA S.A
		BEGIN
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 70, 15.0, NULL, NULL) --TTO 
			IF (@StageTypeId IN (2,3))
			BEGIN
				INSERT  @T_Result
				SELECT  StartDate
					,   EndDate
					,   Time
					,   AdditionalService
					,   AdditionalStartTime
					,   AdditionalEndTime
					,   AdditionalTime
					,   AdditionalQuanty
					,   AdditionalServiceName + ' MTO' AdditionalServiceName
					,   FractionName
					,   TimeLeftover
					,	'MTO' CostCenter
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 15.0, 2, @ServiceHeaderId) --PNTA
			END
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 15.0, 4, @ServiceHeaderId) --PVLO
			IF (@StageTypeId = 14) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO TTO
			IF (@StageTypeId = 5) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 70, 15.0, NULL,NULL) --ESCAL TEC LO MISMO QUE EL TTO VALIDADO CON DOÑA MONICA
			IF (@StageTypeId = 6) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --REG PLATAFORM
			IF (@StageTypeId = 15) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO PCTA

			RETURN
		END

		IF	(@BillingToCompany=1) --?????? / AVIANCA S.A AEROLINEAS NO MAPEADAS EN EL NUEVO CONTRATO MEJOR QUE LO TIRE ADICIONAL
		BEGIN
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL, NULL) --TTO 

			RETURN
		END
	END -- TERMINA BLOQUE CODIGO NUEVO CONTRATO TAKE OFF 20230201

	---------------------------------------------------------------------------------------------
	--OTRO SI NUEVA NEGOCIACION DESPUES 1 OLA COVID CON AVIANCA RESCRIBE A RFP 2016 VER MAS ABAJO
	---------------------------------------------------------------------------------------------
	IF (@DateService BETWEEN '2020-10-01' AND '2023-01-31') 
	BEGIN
		IF (@CompanyId=1 AND @BillingToCompany=1) --AVIANCA S.A / AVIANCA S.A
		BEGIN
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 70, 15.0, NULL, NULL) --TTO 
			IF (@StageTypeId IN (2,3))
			BEGIN
				INSERT  @T_Result
				SELECT  StartDate
					,   EndDate
					,   Time
					,   AdditionalService
					,   AdditionalStartTime
					,   AdditionalEndTime
					,   AdditionalTime
					,   AdditionalQuanty
					,   AdditionalServiceName + ' MTO' AdditionalServiceName
					,   FractionName
					,   TimeLeftover
					,	'MTO' CostCenter
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 15.0, 2, @ServiceHeaderId) --PNTA
			END
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 15.0, 4, @ServiceHeaderId) --PVLO
			IF (@StageTypeId = 14) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO TTO
			IF (@StageTypeId = 5) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 70, 15.0, NULL,NULL) --ESCAL TEC LO MISMO QUE EL TTO VALIDADO CON DOÑA MONICA
			IF (@StageTypeId = 6) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --REG PLATAFORM
			IF (@StageTypeId = 15) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO PCTA

			RETURN
		END

		IF	(	(@CompanyId=58 AND @BillingToCompany=1) --AEROMÉXICO / AVIANCA S.A
			OR	(@CompanyId=43 AND @BillingToCompany=1) --AMERICAN AIRLINES / AVIANCA S.A
			OR	(@CompanyId=63 AND @BillingToCompany=1) --IBERIA / AVIANCA S.A
			OR	(@CompanyId=55 AND @BillingToCompany=1) --JETBLUE / AVIANCA S.A
			OR	(@CompanyId=38 AND @BillingToCompany=1) --TAME / AVIANCA S.A
			)
		BEGIN
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 70, 15.0, NULL, NULL) --TTO 
			IF (@StageTypeId  IN(2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 15.0, 2, @ServiceHeaderId) --PNTA
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 15.0, 4, @ServiceHeaderId) --PVLO
			IF (@StageTypeId = 14) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO TTO
			IF (@StageTypeId = 5) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 70, 15.0, NULL,NULL) --ESCAL TEC LO MISMO QUE EL TTO VALIDADO CON DOÑA MONICA
			IF (@StageTypeId = 6) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --REG PLATAFORM
			IF (@StageTypeId = 15) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO PCTA

			RETURN
		END
	END -- TERMINA BLOQUE CODIGO OTRO SI NUEVA NEGOCIACION DESPUES 1 OLA COVID

	-----------------------------------------------------------------------------------
	--RFP AVA-2016 - EXCLUYE LAS BASES BGA, MTR, IBE, EYP, NVA. PSO
	-----------------------------------------------------------------------------------
	IF (@DateService >= '2016-10-24' AND @AirportId NOT IN (11/*'BGA'*/, 40 /*'MTR'*/, 31 /*'IBE'*/, 25 /*'EYP'*/, 43 /*'NVA'*/, 47 /*'PSO'*/)) --"RFP AVA-2016"
	BEGIN

		------------------------------------------------------------------------------------------------------------
		--**********************************************************************************************************
		------------------------------------------------------------------------------------------------------------
		IF (@CompanyId = 43 AND @BillingToCompany = 1) --AMERICAN AIRLINES - AVIANCA
		BEGIN
			IF (@StageTypeId  IN(2,3)) --PNTA
			BEGIN				
				INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 240, 15.0, 2, @ServiceHeaderId) --MTO PCTA
			END

			IF (@StageTypeId = 4) --PVLO
			BEGIN
				SELECT	@TimeLeftover = MIN(TimeLeftover)
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServiceElectricPlant](														    	
															@ServiceHeaderId,
															@AirportId,
															2,
															@AircraftTypeCode,
															@GroupTypeEnergy,
															@CompanyId,
															@BillingToCompany,
															NULL,
															NULL,
															@DateService)
					
				INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, @TimeLeftover, 15.0, 4, @ServiceHeaderId)
			END

			IF (@StageTypeId = 1) --TTO
			BEGIN
				INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 240, 15.0, NULL, NULL)
			END

			IF (@StageTypeId NOT IN (1, 2, 3, 4)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL, NULL) --OTROS
			
			RETURN
		END

		------------------------------------------------------------------------------------------------------------
		--**********************************************************************************************************
		------------------------------------------------------------------------------------------------------------
		IF (@CompanyId = 64 AND @BillingToCompany = 1) --DELTA AIRLINES - AVIANCA
		BEGIN
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 15.0, NULL, NULL) --TTO
			IF (@StageTypeId IN (2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 15.0, 2, @ServiceHeaderId) --PNTA
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 15.0, 4, @ServiceHeaderId) --PVLO
			IF (@StageTypeId NOT IN (1, 2, 3, 4)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL, NULL) --OTROS
			
			RETURN
		END
	
		------------------------------------------------------------------------------------------------------------
		--**********************************************************************************************************
		------------------------------------------------------------------------------------------------------------
		IF (@CompanyId = 65 AND @BillingToCompany = 1) --AEROPOSTAL A AVIANCA
		BEGIN
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 15.0, NULL, NULL) --TTO 
			IF (@StageTypeId NOT IN (1)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL, NULL) --OTROS
			
			RETURN
		END

		------------------------------------------------------------------------------------------------------------
		--**********************************************************************************************************
		------------------------------------------------------------------------------------------------------------
		IF	(@CompanyId = 1 AND @BillingToCompany = 1) --AVIANCA A AVIANCA
		BEGIN
					
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 15.0, NULL, NULL) --TTO 
			IF (@StageTypeId  IN(2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 15.0, 2, @ServiceHeaderId) --PNTA
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 15.0, 4, @ServiceHeaderId) --PVLO
			IF (@StageTypeId = 14) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO TTO
			IF (@StageTypeId = 5) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 15.0, NULL,NULL) --ESCAL TEC LO MISMO QUE EL TTO VALIDADO CON DOÑA MONICA
			IF (@StageTypeId = 6) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --REG PLATAFORM
			IF (@StageTypeId = 15) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO PCTA

			RETURN
		END

		------------------------------------------------------------------------------------------------------------
		--**********************************************************************************************************
		------------------------------------------------------------------------------------------------------------
		IF	(	(@BillingToCompany = 1 AND @CompanyId NOT IN(55,42,38,47,37)) OR --AVIANCA SERVICES (EXCEPTO JETBLUE, TACA, TAME, AEROGAL, SATENA VER MAS ABAJO LA REGLA HA VARIADO)
				(@CompanyId = 42 AND @BillingToCompany IN (42,54)) OR --TACA A TACA Y TACA A TRANS AMERICAN
				(@CompanyId = 41 AND @BillingToCompany = 41) --LACSA A LACSA
			) 
		BEGIN
					
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 15.0, NULL, NULL) --TTO 
			IF (@StageTypeId  IN(2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 15.0, 2, @ServiceHeaderId) --PNTA
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 15.0, 4,@ServiceHeaderId) --PVLO
			IF (@StageTypeId = 14) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO TTO
			IF (@StageTypeId = 5) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 15.0, NULL,NULL) --ESCAL TEC LO MISMO QUE EL TTO VALIDADO CON DOÑA MONICA
			IF (@StageTypeId = 6) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --REG PLATAFORM
			IF (@StageTypeId = 15) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO PCTA

			RETURN
		END

		------------------------------------------------------------------------------------------------------------
		--**********************************************************************************************************
		------------------------------------------------------------------------------------------------------------
		IF (@CompanyId = 37 AND @BillingToCompany = 1) --SATENA - AVIANCA
		BEGIN
			IF (@AirportId IN (11 /*'BGA'*/, 18 /*'CUC'*/))
			BEGIN				
			    
				IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 15.0, NULL, NULL) --TTO 
				IF (@StageTypeId IN(2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 90, 15.0, 2, @ServiceHeaderId) --PNTA
				IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 15.0, 4, @ServiceHeaderId) --PVLO 
				IF (@StageTypeId NOT IN (1,2,3,4)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL, NULL) --OTROS
				
				RETURN
			END
			
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 15.0, NULL, NULL) --TTO 
			IF (@StageTypeId  IN(2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 15.0, 2, @ServiceHeaderId) --PNTA
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 15.0, 4,@ServiceHeaderId) --PVLO
			IF (@StageTypeId = 14) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO TTO
			IF (@StageTypeId = 5) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 15.0, NULL,NULL) --ESCAL TEC LO MISMO QUE EL TTO VALIDADO CON DOÑA MONICA
			IF (@StageTypeId = 6) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --REG PLATAFORM
			IF (@StageTypeId = 15) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO PCTA

			RETURN
		END

		------------------------------------------------------------------------------------------------------------
		--**********************************************************************************************************
		------------------------------------------------------------------------------------------------------------
		IF (@CompanyId = 55 AND @BillingToCompany = 1) --JETBLUE
		BEGIN
		
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 15.0, NULL, NULL) --TTO 
			IF (@StageTypeId  IN(2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 15.0, 2, @ServiceHeaderId) --PNTA
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 15.0, 4,@ServiceHeaderId) --PVLO
			IF (@StageTypeId = 14) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO TTO
			IF (@StageTypeId = 5) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 15.0, NULL,NULL) --ESCAL TEC LO MISMO QUE EL TTO VALIDADO CON DOÑA MONICA
			IF (@StageTypeId = 6) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --REG PLATAFORM
			IF (@StageTypeId = 15) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO PCTA
				
			RETURN
		END

		------------------------------------------------------------------------------------------------------------
		--**********************************************************************************************************
		------------------------------------------------------------------------------------------------------------
		IF	(	(@CompanyId IN (42,38,47) AND @BillingToCompany = 1) OR --TACA A AVIANCA, TAME A AVIANCA, AEROGAL A AVIANCA
				(@CompanyId = 47 AND @BillingToCompany = 47) --AEROGAL A AEROGAL
			)
		BEGIN			

			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 15.0, NULL, NULL) --TTO 
			IF (@StageTypeId  IN(2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 15.0, 2, @ServiceHeaderId) --PNTA
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 15.0, 4,@ServiceHeaderId) --PVLO
			IF (@StageTypeId = 14) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO TTO
			IF (@StageTypeId = 5) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 15.0, NULL,NULL) --ESCAL TEC LO MISMO QUE EL TTO VALIDADO CON DOÑA MONICA
			IF (@StageTypeId = 6) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --REG PLATAFORM
			IF (@StageTypeId = 15) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL,NULL) --MTO PCTA

			RETURN
		END

	END --TERMINA BLOQUE CODIGO "RFP AVA-2016"

	------------------------------------------------------------
	--ANTES DEL RFP AVA-2016
	------------------------------------------------------------
	IF (@DateService < '2016-10-24' OR @AirportId IN (11/*'BGA'*/, 40 /*'MTR'*/, 31 /*'IBE'*/, 25 /*'EYP'*/, 43 /*'NVA'*/, 47 /*'PSO'*/)) --ANTES DEL RFP AVA-2016
	BEGIN
		IF (@CompanyId = 64 AND @BillingToCompany = 1) --DELTA AIRLINES - AVIANCA
		BEGIN
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 30.0, NULL, NULL) --TTO
			IF (@StageTypeId IN (2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 30.0, 2, @ServiceHeaderId) --PNTA
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, 4, @ServiceHeaderId) --PVLO
			IF (@StageTypeId NOT IN (1, 2, 3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL) --OTROS
			
			RETURN
		END

		IF (@CompanyId = 65 AND @BillingToCompany = 1) --AEROPOSTAL - AVIANCA
		BEGIN
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 30.0, NULL, NULL) --TTO 
			IF (@StageTypeId NOT IN (1)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL) --OTROS
			
			RETURN
		END
        
		IF	(	(@CompanyId = 1 AND @BillingToCompany = 1) OR --AVIANCA A AVIANCA
				(@CompanyId = 193 AND @BillingToCompany = 1) OR --REGIONAL EXPRESS AMERICAS A AVIANCA
				(@BillingToCompany = 1 AND @CompanyId NOT IN(55,42,38,47,37)) OR --AVIANCA SERVICES (EXCEPTO JETBLUE, TACA, TAME, AEROGAL, SATENA VER MAS ABAJO LA REGLA HA VARIADO)
				(@CompanyId = 42 AND @BillingToCompany IN (42,54)) OR --TACA A TACA Y TACA A TRANS AMERICAN
				(@CompanyId = 41 AND @BillingToCompany = 41) --LACSA A LACSA
			) 
		BEGIN
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 30.0, NULL, NULL) --TTO 
			IF (@StageTypeId  IN(2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 30.0, 2, @ServiceHeaderId) --PNTA
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, 4,@ServiceHeaderId) --PVLO
			IF (@StageTypeId = 14) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL,NULL) --MTO TTO
			IF (@StageTypeId = 5) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 30.0, NULL,NULL) --ESCAL TEC LO MISMO QUE EL TTO VALIDADO CON DOÑA MONICA
			IF (@StageTypeId = 6) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL,NULL) --REG PLATAFORM
			IF (@StageTypeId = 15) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL,NULL) --MTO PCTA
			
			RETURN
		END
		
		IF (@CompanyId = 37 AND @BillingToCompany = 1) --SATENA - AVIANCA
		BEGIN
			IF (@AirportId IN (11 /*'BGA'*/, 18 /*'CUC'*/))
			BEGIN
				IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 30.0, NULL, NULL) --TTO 
				IF (@StageTypeId IN(2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 90, 30.0, 2, @ServiceHeaderId) --PNTA
				IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 30.0, 4, @ServiceHeaderId) --PVLO 
				IF (@StageTypeId NOT IN (1,2,3,4)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL) --OTROS

				RETURN
			END
			
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 30.0, NULL, NULL) --TTO 
			IF (@StageTypeId  IN(2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 30.0, 2, @ServiceHeaderId) --PNTA
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, 4,@ServiceHeaderId) --PVLO
			IF (@StageTypeId = 14) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL,NULL) --MTO TTO
			IF (@StageTypeId = 5) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 30.0, NULL,NULL) --ESCAL TEC LO MISMO QUE EL TTO VALIDADO CON DOÑA MONICA
			IF (@StageTypeId = 6) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL,NULL) --REG PLATAFORM
			IF (@StageTypeId = 15) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL,NULL) --MTO PCTA
			RETURN
		END

		IF (@CompanyId = 55 AND @BillingToCompany = 1) --JETBLUE - AVIANCA
		BEGIN
			IF (@DateService < '2014-09-16')
			BEGIN
				
				IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 60.0, NULL, NULL) --TTO 
				IF (@StageTypeId IN(2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 60.0, 2, @ServiceHeaderId) --PNTA
				IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 60.0, 4, @ServiceHeaderId) --PVLO 
				IF (@StageTypeId NOT IN (1,2,3,4)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 60.0, NULL, NULL) --LOS DEMAS ??? 1
								
				RETURN
			END
			
			IF (@DateService >= '2014-09-16')
			BEGIN
			
				IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 30.0, NULL, NULL) --TTO 
				IF (@StageTypeId  IN(2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 30.0, 2, @ServiceHeaderId) --PNTA
				IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, 4,@ServiceHeaderId) --PVLO
				IF (@StageTypeId = 14) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL,NULL) --MTO TTO
				IF (@StageTypeId = 5) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 30.0, NULL,NULL) --ESCAL TEC LO MISMO QUE EL TTO VALIDADO CON DOÑA MONICA
				IF (@StageTypeId = 6) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL,NULL) --REG PLATAFORM
				IF (@StageTypeId = 15) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL,NULL) --MTO PCTA
				
				RETURN
			END

			IF	(	(@CompanyId IN(42,38,47) AND @BillingToCompany = 1) OR --TACA A AVIANCA, TAME A AVIANCA, AEROGAL A AVIANCA
					(@CompanyId = 47 AND @BillingToCompany = 47) --AEROGAL A AEROGAL
				)
			BEGIN
				IF (@DateService < '2014-09-16')
				BEGIN
								
					IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 60.0, NULL, NULL) --TTO 
					IF (@StageTypeId  IN(2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 60.0, 2, @ServiceHeaderId) --PNTA
					IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 60.0, 4,@ServiceHeaderId) --PVLO
					IF (@StageTypeId = 14) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 60.0, NULL,NULL) --MTO TTO
					IF (@StageTypeId = 5) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 60.0, NULL,NULL) --ESCAL TEC LO MISMO QUE EL TTO VALIDADO CON DOÑA MONICA
					IF (@StageTypeId = 6) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 60.0, NULL,NULL) --REG PLATAFORM
					IF (@StageTypeId = 15) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 60.0, NULL,NULL) --MTO PCTA

					RETURN
				END
			
				IF (@DateService >= '2014-09-16')
				BEGIN
			
					IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 30.0, NULL, NULL) --TTO 
					IF (@StageTypeId  IN(2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 30.0, 2, @ServiceHeaderId) --PNTA
					IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, 4,@ServiceHeaderId) --PVLO
					IF (@StageTypeId = 14) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL,NULL) --MTO TTO
					IF (@StageTypeId = 5) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 30.0, NULL,NULL) --ESCAL TEC LO MISMO QUE EL TTO VALIDADO CON DOÑA MONICA
					IF (@StageTypeId = 6) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL,NULL) --REG PLATAFORM
					IF (@StageTypeId = 15) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL,NULL) --MTO PCTA

					RETURN
				END
			END


		END
    END -- TERMINA BLOQUE CODIGO "ANTES DEL RFP AVA-2016"

	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	IF (@CompanyId = 44 /*OR @BillingToCompany = 7 ESTÁ INACTIVA EN EL AT*/) --LAN AIRLINES / AIRES - LATAM
	BEGIN
		IF (@DateService >= '2021-02-01' AND @AirportId = 47) -- PSO
		BEGIN
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, NULL, NULL) --TTOS
			IF (@StageTypeId NOT IN (1)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL) --OTROS
			
			RETURN
		END

		IF (@DateService >= '2021-06-05' AND @AirportId = 9) -- AXM
		BEGIN
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, NULL, NULL) --TTOS
			IF (@StageTypeId NOT IN (1)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL) --OTROS
			
			RETURN
		END

		IF (@DateService >= '2021-10-27' AND @AirportId = 25) -- EYP
		BEGIN
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL) --TTOS
			IF (@StageTypeId NOT IN (1)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL) --OTROS
			
			RETURN
		END
		
		IF (@DateService >= '2023-03-27' AND @AirportId = 51) -- RCH
		BEGIN
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL) --TTOS
			IF (@StageTypeId NOT IN (1)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL) --OTROS
			
			RETURN
		END

		IF (@AirportId = 5) -- ADZ
		BEGIN
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, NULL, NULL) --TTOS
			IF (@StageTypeId NOT IN (1)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL) --OTROS
			
			RETURN
		END
		
		IF (@AirportId IN (3, 4)) -- RNG, CLO
		BEGIN
			IF (@StageTypeId = 1) --TTOS
			BEGIN
				IF (@AircraftTypeCode = 'DASH8')
					INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 30.0, NULL, NULL)
				ELSE
					INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, NULL, NULL)
			END		
			IF (@StageTypeId IN (2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 30.0, 2, @ServiceHeaderId) --PNTA
			IF (@StageTypeId = 13) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 30.0, NULL, NULL) --LIMPIEZA TERMINAL				
			IF (@StageTypeId NOT IN (1,2,3,13)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL) --OTROS
			
			RETURN
		END
	
		IF(@AirportId = 10) -- BAQ
		BEGIN
			IF (@StageTypeId IN (2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 30.0, 2, @ServiceHeaderId) --PNTA
			IF (@StageTypeId = 13) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 30.0, NULL, NULL) --LIMPIEZA TERMINAL				
			IF (@StageTypeId NOT IN (2,3,13)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL) --OTROS
			
			RETURN
		END

		IF (@AirportId = 17) -- CTG
		BEGIN
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, NULL, NULL) --TTO
			IF (@StageTypeId IN(2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, 2, @ServiceHeaderId) --PNTA
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, 4, @ServiceHeaderId) --PVLO
			IF (@StageTypeId = 13) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 30.0, NULL, NULL) --LIMPIEZA TERMINAL
			IF (@StageTypeId NOT IN (1, 2, 3, 4, 13)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL) --OTROS
			
			RETURN
		END
		
		IF (@AirportId = 11) -- BGA
		BEGIN
			IF (@StageTypeId = 1) --TTO
			BEGIN
				IF (@AircraftTypeCode = 'DASH8')
					INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 30.0, NULL, NULL)
				ELSE
					INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, NULL, NULL)
			END
			IF (@StageTypeId IN (2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 30.0, 2, @ServiceHeaderId) --PNTA
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, 4, @ServiceHeaderId) --PVLO
			IF (@StageTypeId NOT IN (1, 2, 3, 4)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL) --OTROS
			
			RETURN
		END
			
		IF (@AirportId = 23) -- EOH
		BEGIN
			IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 40, 30.0, NULL, NULL) --TTO
			IF (@StageTypeId IN (2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 150, 30.0, 2, @ServiceHeaderId) --PNTA
			IF (@StageTypeId = 13) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 30.0, NULL, NULL) --LIMPIEZA TERMINAL				
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, 4, @ServiceHeaderId) --PREVUELO
			IF (@StageTypeId NOT IN (1, 2, 3, 8, 4)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL) --OTROS
			
			RETURN
		END		
	
		BEGIN -- REGLA OBSOLETA ANTIGUA GENERAL
			IF (@StageTypeId = 1) --TTOS
			BEGIN
				IF (@AircraftTypeCode = 'DASH8')
					INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 30.0, NULL, NULL)
				ELSE
					INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, NULL, NULL)
			END
			IF (@StageTypeId IN(2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 30.0, 2, @ServiceHeaderId) --PNTA
			IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 30.0, 4, @ServiceHeaderId) --PVLO
			IF (@StageTypeId NOT IN (1, 2, 3, 4)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL) --OTROS
			
			RETURN
		END

		RETURN
	END

	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	IF (@CompanyId = 37 AND @BillingToCompany <> 1) --SATENA  - <> AVIANCA                            
	BEGIN
		IF (@BillingToCompany = 36) --GAMA                              
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL)
		ELSE
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 30.0, NULL, NULL)

		RETURN
	END

	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	IF (@CompanyId = 3 AND @BillingToCompany <> 3) --ADA                              
	BEGIN
		IF (@AirportId = 11 /*'BGA'*/ AND @DateService BETWEEN '2018-02-10' AND '2018-02-17' ) --OPERACION TEMPORAL BGA
		BEGIN
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, NULL, NULL)
			RETURN
		END
		
		INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 15, 30.0, NULL, NULL)
		RETURN
	END
	
		------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	IF (@CompanyId = 11 AND @BillingToCompany = 11) --EASY FLY                              
	BEGIN
		IF (@StageTypeId = 1) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 30.0, NULL, NULL)
		IF (@StageTypeId IN (2,3)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 30.0, 2, @ServiceHeaderId)
		IF (@StageTypeId = 4) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 30.0, 3 ,@ServiceHeaderId)
		IF (@StageTypeId NOT IN (1,2,3,4)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL)

		RETURN
	END

	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	IF (@CompanyId = 66 AND @BillingToCompany = 89) --LC PERÚ - AVENTURS                            
	BEGIN		
		INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 30.0, NULL, NULL)
		RETURN
	END
	
	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	IF (@CompanyId = 192 AND @BillingToCompany = 192) --VIVA PERU  - VIVA PERU                       
	BEGIN
		IF (@StageTypeId IN (3, 13)) -- ETAPAS DE LIMPIEZA TERMINAL (PCTA) y LIMPIEZA TERMINAL
		BEGIN
			IF (@DateService >= '2016-06-01' AND @DateService <= '2020-01-31')
			BEGIN
				RETURN -- SE MANEJÓ BOLSA A NIVEL NACIONAL X MATRICULA HASTA EL 2020-01-31 (MANTENIMIENTO)
			END

			IF (@DateService >= '2020-02-01')
			BEGIN 
				IF (@StageTypeId = 3) --ETAPA: LIMPIEZA TERMINAL (PCTA)
				BEGIN
					INSERT   @T_Result
					SELECT   StartDate
						,    EndDate
						,    Time
						,    AdditionalService
						,    AdditionalStartTime
						,    AdditionalEndTime
						,    AdditionalTime
						,    AdditionalQuanty
						,    AdditionalServiceName + ' MTO' AdditionalServiceName
						,    FractionName
						,    TimeLeftover
						,	 'MTO' CostCenter
					FROM     [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetail, 0, 60.0, '3', @ServiceHeaderId) --OJO NUEVA VERSION DE LA FUNCION
					RETURN
				END
				IF (@StageTypeId = 13) --ETAPA: LIMPIEZA TERMINAL
				BEGIN
					INSERT   @T_Result
					SELECT   StartDate
						,    EndDate
						,    Time
						,    AdditionalService
						,    AdditionalStartTime
						,    AdditionalEndTime
						,    AdditionalTime
						,    AdditionalQuanty
						,    AdditionalServiceName + ' MTO' AdditionalServiceName
						,    FractionName
						,    TimeLeftover
						,	 'MTO' CostCenter
					FROM     [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetail, 0, 60.0, '*', @ServiceHeaderId) --OJO NUEVA VERSION DE LA FUNCION
					RETURN
				END
			END
        END

		-----------------------------------------------------------------------------
		--PARA LOS SERVICIOS RESTANTES DIFERENTES A LIMPIEZAS EN PERNOCTAS Y TERMINAL

		IF (@DateService >= '2016-06-01')
		BEGIN
			RETURN -- DESDE ESTA FECHA SE MANEJA BOLSA A NIVEL NACIONAL (RAMPA)
		END
	END

	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	IF (@CompanyId = 60 AND @BillingToCompany = 90) --VIVA COLOMBIA FACTURAR A FAST COLOMBIA                            
	BEGIN
		IF (@StageTypeId IN (3, 13)) -- ETAPAS DE LIMPIEZA TERMINAL (PCTA) y LIMPIEZA TERMINAL
		BEGIN
			IF (@DateService >= '2016-06-01' AND @DateService <= '2020-01-31')
			BEGIN
				RETURN -- SE MANEJÓ BOLSA A NIVEL NACIONAL X MATRICULA HASTA EL 2020-01-31 (MANTENIMIENTO)
			END

			IF (@DateService >= '2020-02-01')
			BEGIN
				IF (CIOServicios.UFN_CIO_InternationalFlight(@AirportId, @DestinationId) = 1)
				BEGIN
					SET @ExtraText = ' INTERNACIONAL'
				END

				IF (@StageTypeId = 3) --ETAPA: LIMPIEZA TERMINAL (PCTA)
				BEGIN
					INSERT   @T_Result
					SELECT   StartDate
						,    EndDate
						,    Time
						,    AdditionalService
						,    AdditionalStartTime
						,    AdditionalEndTime
						,    AdditionalTime
						,    AdditionalQuanty
						,    AdditionalServiceName + @ExtraText + ' MTO' AdditionalServiceName
						,    FractionName
						,    TimeLeftover
						,	 'MTO' CostCenter
					FROM     [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetail, 0, 60.0, '3', @ServiceHeaderId) --OJO NUEVA VERSION DE LA FUNCION
					RETURN
				END
				IF (@StageTypeId = 13) --ETAPA: LIMPIEZA TERMINAL
				BEGIN
					INSERT   @T_Result
					SELECT   StartDate
						,    EndDate
						,    Time
						,    AdditionalService
						,    AdditionalStartTime
						,    AdditionalEndTime
						,    AdditionalTime
						,    AdditionalQuanty
						,    AdditionalServiceName + @ExtraText + ' MTO' AdditionalServiceName
						,    FractionName
						,    TimeLeftover
						,	 'MTO' CostCenter
					FROM     [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetail, 0, 60.0, '*', @ServiceHeaderId) --OJO NUEVA VERSION DE LA FUNCION
					RETURN
				END
			END
		END

		-----------------------------------------------------------------------------
		--PARA LOS SERVICIOS RESTANTES DIFERENTES A LIMPIEZAS EN PERNOCTAS Y TERMINAL

		IF (@DateService BETWEEN '2016-06-01' AND '2020-08-31') --SE MANEJÓ BOLSA HASTA OTRO SI VIVA COVID QUE QUITA LA BOLSA
		BEGIN
			RETURN -- DESDE ESTA FECHA SE MANEJA BOLSA A NIVEL NACIONAL (RAMPA)
		END

		IF (@DateService >= '2021-11-01') --CONFIGURACION OTRO SI VIVA COVID QUITA LA BOLSA YA SE FACTURA ADICIONAL LA PLANTA Y SE MANEJA EL COBRO DE LOS 45 MINUTOS DESDE EL PRIMER VUELO Y LO QUE QUEDA EN EL ULTIMO VUELO
		BEGIN
			IF (CIOServicios.UFN_CIO_InternationalFlight(@AirportId, @DestinationId) = 1)
			BEGIN
				SET @ExtraText = ' INTERNACIONAL'
			END

			IF (@StageTypeId = 4) --ETAPA PRIMER VUELO
			BEGIN			
				INSERT	@T_Result
				SELECT	StartDate
					,	EndDate
					,	Time
					,	AdditionalService
					,	AdditionalStartTime
					,	AdditionalEndTime
					,	AdditionalTime
					,	AdditionalQuanty
					,   AdditionalServiceName + @ExtraText + ' RAMPA' AdditionalServiceName
					,	FractionName
					,	TimeLeftover
					,	NULL CostCenter
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetail, 45, 30.0, '4', @ServiceHeaderId)  --OJO NUEVA VERSION DE LA FUNCION
				RETURN
			END

			IF (@StageTypeId = 2) --ETAPA OJO!! SOLO ULTIMO VUELO (En este cliente es a la inversa primero se descuenta del primer vuelo y lo que queda se descuenta en el último vuelo
			BEGIN	
				SELECT	@TimeLeftover = MIN(TimeLeftover)
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServiceElectricPlant](														    	
															@ServiceHeaderId,
															@AirportId,
															4,
															@AircraftTypeCode,
															@GroupTypeEnergy,
															@CompanyId,
															@BillingToCompany,
															NULL,
															NULL,
															@DateService) --COMPARTE TIEMPO SOLO CON LA ETAPA DE ULTIMO VUELO OJO!! EL TIEMPO LA LIMPIEZA ES APARTE EN OTRO CONTRATO

				INSERT	@T_Result
				SELECT	StartDate
					,	EndDate
					,	Time
					,	AdditionalService
					,	AdditionalStartTime
					,	AdditionalEndTime
					,	AdditionalTime
					,	AdditionalQuanty
					,   AdditionalServiceName + @ExtraText + ' RAMPA' AdditionalServiceName
					,	FractionName
					,	TimeLeftover
					,	NULL CostCenter
				FROM    [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetail, @TimeLeftover, 30.0, '2', @ServiceHeaderId)  --OJO NUEVA VERSION DE LA FUNCION
				RETURN
			END

			IF (@StageTypeId = 1) --ETAPA TRANSITO
			BEGIN
				INSERT	@T_Result
				SELECT	StartDate
					,	EndDate
					,	Time
					,	AdditionalService
					,	AdditionalStartTime
					,	AdditionalEndTime
					,	AdditionalTime
					,	AdditionalQuanty
					,   AdditionalServiceName + @ExtraText + ' RAMPA' AdditionalServiceName
					,	FractionName
					,	TimeLeftover
					,	NULL CostCenter
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetail, 45, 30.0, '*', @ServiceHeaderId)  --OJO NUEVA VERSION DE LA FUNCION
				RETURN
			END

			IF (@StageTypeId IN (5,6)) --ETAPAS ESCALAS TECNICAS / REGRESOS A PLATAFORMA
			BEGIN
				INSERT	@T_Result
				SELECT	StartDate
					,	EndDate
					,	Time
					,	AdditionalService
					,	AdditionalStartTime
					,	AdditionalEndTime
					,	AdditionalTime
					,	AdditionalQuanty
					,   AdditionalServiceName + @ExtraText + ' RAMPA' AdditionalServiceName
					,	FractionName
					,	TimeLeftover
					,	NULL CostCenter
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetail, 0, 30.0, '*', @ServiceHeaderId)  --OJO NUEVA VERSION DE LA FUNCION
				RETURN
			END
		END

		IF (@DateService BETWEEN '2020-09-01' AND '2021-10-31') --CONFIGURACION OTRO SI VIVA COVID QUITA LA BOLSA YA SE FACTURA ADICIONAL LA PLANTA
		BEGIN
			IF (@StageTypeId = 2) --ETAPA OJO!! SOLO ULTIMO VUELO
			BEGIN			
				INSERT	@T_Result
				SELECT	StartDate
					,	EndDate
					,	Time
					,	AdditionalService
					,	AdditionalStartTime
					,	AdditionalEndTime
					,	AdditionalTime
					,	AdditionalQuanty
					,   AdditionalServiceName + ' RAMPA' AdditionalServiceName
					,	FractionName
					,	TimeLeftover
					,	NULL CostCenter
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetail, 45, 30.0, '2', @ServiceHeaderId)  --OJO NUEVA VERSION DE LA FUNCION
				RETURN
			END

			IF (@StageTypeId = 4) --ETAPA PRIMER VUELO
			BEGIN	
				SELECT	@TimeLeftover = MIN(TimeLeftover)
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServiceElectricPlant](														    	
															@ServiceHeaderId,
															@AirportId,
															2,
															@AircraftTypeCode,
															@GroupTypeEnergy,
															@CompanyId,
															@BillingToCompany,
															NULL,
															NULL,
															@DateService) --COMPARTE TIEMPO SOLO CON LA ETAPA DE ULTIMO VUELO OJO!! EL TIEMPO LA LIMPIEZA ES APARTE EN OTRO CONTRATO

				INSERT	@T_Result
				SELECT	StartDate
					,	EndDate
					,	Time
					,	AdditionalService
					,	AdditionalStartTime
					,	AdditionalEndTime
					,	AdditionalTime
					,	AdditionalQuanty
					,   AdditionalServiceName + ' RAMPA' AdditionalServiceName
					,	FractionName
					,	TimeLeftover
					,	NULL CostCenter
				FROM    [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetail, @TimeLeftover, 30.0, '4', @ServiceHeaderId)  --OJO NUEVA VERSION DE LA FUNCION
				RETURN
			END

			IF (@StageTypeId = 1) --ETAPA TRANSITO
			BEGIN
				INSERT	@T_Result
				SELECT	StartDate
					,	EndDate
					,	Time
					,	AdditionalService
					,	AdditionalStartTime
					,	AdditionalEndTime
					,	AdditionalTime
					,	AdditionalQuanty
					,   AdditionalServiceName + ' RAMPA' AdditionalServiceName
					,	FractionName
					,	TimeLeftover
					,	NULL CostCenter
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetail, 45, 30.0, '*', @ServiceHeaderId)  --OJO NUEVA VERSION DE LA FUNCION
				RETURN
			END

			IF (@StageTypeId IN (5,6)) --ETAPAS ESCALAS TECNICAS / REGRESOS A PLATAFORMA
			BEGIN
				INSERT	@T_Result
				SELECT	StartDate
					,	EndDate
					,	Time
					,	AdditionalService
					,	AdditionalStartTime
					,	AdditionalEndTime
					,	AdditionalTime
					,	AdditionalQuanty
					,   AdditionalServiceName + ' RAMPA' AdditionalServiceName
					,	FractionName
					,	TimeLeftover
					,	NULL CostCenter
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetail, 0, 30.0, '*', @ServiceHeaderId)  --OJO NUEVA VERSION DE LA FUNCION
				RETURN
			END
		END

		---REGLAS ANTIGUAS

		IF (@AirportId = 25 /*'EYP'*/) --EYP
		BEGIN			
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 30.0, NULL, NULL)
			RETURN
		END

		IF (@AirportId = 34 /*'LET'*/) --LET
		BEGIN			
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 25.0, NULL, NULL)
			RETURN
		END

		IF (@AirportId = 59 /*'VUP'*/) --VUP
		BEGIN			
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 25.0, NULL, NULL)
			RETURN
		END

		RETURN
	END
	  
	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	IF (@CompanyId = 69 AND @BillingToCompany = 69) --SARPA FACTURAR A SARPA                            
	BEGIN
		IF (@StageTypeId = 1) --TTO
		BEGIN			
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 80, 30.0, NULL, @ServiceHeaderId)
		END

		IF (@StageTypeId IN (2,3)) --PNTA
		BEGIN			

			DECLARE @CleaningActivity INT = (SELECT COUNT(1) FROM CIOServicios.DetalleServicio WHERE EncabezadoServicioId = @ServiceHeaderId AND TipoActividadId = 24 /*LIMPIEZA*/ AND Activo = 1 )

			IF (@CleaningActivity > 0)
			    BEGIN -- SI  EXISTE ACTIVIDAD LIMPIEZA
						INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 125, 30.0, 2, @ServiceHeaderId) --Se adicionan 45 MINUTOS a los 80 existentes cuando existe la Limpieza en PCTA
				END
		    ELSE 
			    BEGIN
					   INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 80, 30.0, 2, @ServiceHeaderId)
				END
			
		END

		IF (@StageTypeId = 4) --PVLO
		BEGIN
			SELECT	@TimeLeftover = MIN(TimeLeftover)
			FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServiceElectricPlant](														    	
														@ServiceHeaderId,
														@AirportId,
														2,
														@AircraftTypeCode,
														@GroupTypeEnergy,
														@CompanyId,
														@BillingToCompany,
														NULL,
														NULL,
														@DateService)
					
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, @TimeLeftover, 30.0, 4, @ServiceHeaderId)	
		END			    

		IF (@StageTypeId NOT IN (1,2,3,4)) --OTROS
		BEGIN			
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL)
		END

		RETURN
	END

	  ------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	IF (@CompanyId = 69 AND @BillingToCompany = 90) --SARPA FACTURAR A FAST COLOMBIA                            
	BEGIN	
		INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 25.0, NULL, NULL)
		RETURN
	
	END

	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	IF (@CompanyId = 37 AND @BillingToCompany = 90) --SATENA FACTURAR A FAST COLOMBIA                            
	BEGIN	
		INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 25.0, NULL, NULL)
		RETURN
	END	

	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	IF (@CompanyId = 72 AND @BillingToCompany = 56) --WINGO  - AEROREPUBLICA                  
	BEGIN
		IF (@DateService <= '2019-06-30')
		BEGIN
			IF (@AirportId = 17 /*'CTG'*/ AND @StageTypeId IN (2,3))
			BEGIN				
				INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 30.0, 2, @ServiceHeaderId)
				RETURN
			END
				
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 30.0, NULL, NULL)
			RETURN
		END
		ELSE
		BEGIN
			IF (@StageTypeId = 1) 
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 30, 15.0, NULL, NULL) --TTO

			IF (@StageTypeId IN (2,3)) --PNTA
			BEGIN				
				INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 150, 15.0, 2, @ServiceHeaderId) --PCTA
			END

			IF (@StageTypeId = 4) --PVLO
			BEGIN			
				SELECT	@TimeLeftover = MIN(TimeLeftover)
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServiceElectricPlant](														    	
															@ServiceHeaderId,
															@AirportId,
															2,
															@AircraftTypeCode,
															@GroupTypeEnergy,
															@CompanyId,
															@BillingToCompany,
															NULL,
															NULL,
															@DateService)
					
				INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, @TimeLeftover, 15.0, 4, @ServiceHeaderId)

			END

			IF (@StageTypeId NOT IN (1,2,3,4)) 
			    INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL, NULL) --OTROS

			RETURN
		END
	END

	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	IF (@CompanyId = 9) --COPA                          
	BEGIN
	     
		IF (@DateService <= '2014-09-25')
		BEGIN		  
			IF (@StageTypeId = 1) 
			   INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, NULL, NULL)
		
			IF (@StageTypeId IN (2,3)) --PNTA
			BEGIN
				IF (@AirportId = 11 /*'BGA'*/)
				BEGIN
					IF (@OriginId = 48 /*PTY*/) --PTY CIUDAD DE PANAMA
					    INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 30.0, 2, @ServiceHeaderId)

					IF (@OriginId = 12 /*BOG*/) --BOG BOGOTA
					    INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 150, 30.0, 2, @ServiceHeaderId)

					IF (@OriginId NOT IN (48, 12))--NO PTY NI BOG
					    INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 30.0, 2, @ServiceHeaderId)

				END
				ELSE
				BEGIN					
					INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 30.0, 2, @ServiceHeaderId)
				END
			END

			IF (@StageTypeId = 4) --PVLO
			BEGIN
				IF (@AirportId = 11 /*'BGA'*/)
				BEGIN
					IF (@DestinationId = 48) --PTY CIUDAD DE PANAMA
					    INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 30.0, 4, @ServiceHeaderId)

					IF (@DestinationId = 12) --BOG
					    INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 90, 30.0, 4, @ServiceHeaderId)

					IF (@DestinationId NOT IN (48, 12)) --NO PTY NI BOG
					    INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 180, 30.0, 4, @ServiceHeaderId)
				END
				ELSE
				BEGIN					
					INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, 4, @ServiceHeaderId)
				END
			END
			
			IF (@StageTypeId NOT IN (1,2,3,4)) INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL) --OTROS
		END
		ELSE IF (@DateService BETWEEN '2014-09-26' AND '2019-06-30')
		BEGIN		 
			IF (@StageTypeId = 1) 
			   INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, NULL, NULL) --TTO

			IF (@StageTypeId IN (2,3)) --PNTA
			BEGIN			
				INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 240, 30.0, 2, @ServiceHeaderId)
			END

			IF (@StageTypeId = 4) --PVLO
			BEGIN
			
				SELECT	@TimeLeftover = MIN(TimeLeftover)
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServiceElectricPlant](														    	
															@ServiceHeaderId,
															@AirportId,
															2,
															@AircraftTypeCode,
															@GroupTypeEnergy,
															@CompanyId,
															@BillingToCompany,
															NULL,
															NULL,
															@DateService)
					
				INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, @TimeLeftover, 30.0, 4, @ServiceHeaderId)

			END

			IF (@StageTypeId NOT IN (1,2,3,4)) --OTROS
			    INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL)
		END
		ELSE --REGLA VIGENTE A PARTIR DE 2019-07-01
		BEGIN

			IF (@StageTypeId = 1)--TTO
			   INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 15.0, NULL, NULL)

			IF (@StageTypeId IN(2,3)) --PNTA
			BEGIN				
				INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 150, 15.0, 2, @ServiceHeaderId)
			END

			IF (@StageTypeId = 4) --PVLO
			BEGIN
				
				SELECT	@TimeLeftover = MIN(TimeLeftover)
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServiceElectricPlant](														    	
															@ServiceHeaderId,
															@AirportId,
															2,
															@AircraftTypeCode,
															@GroupTypeEnergy,
															@CompanyId,
															@BillingToCompany,
															NULL,
															NULL,
															@DateService)
					
				INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, @TimeLeftover, 15.0, 4, @ServiceHeaderId)

			END
			
			IF (@StageTypeId NOT IN (1,2,3,4))--OTROS
			   BEGIN
			   INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0, NULL, NULL)
 
			   END
			    
		END

		RETURN
	END

	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	IF (@CompanyId = 205 AND @BillingToCompany = 205) --ARUBA AIRLINES
	BEGIN		
		INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, NULL, NULL)

		RETURN
	END

	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	IF (@CompanyId = 70 AND @BillingToCompany = 70) --INTERJET
	BEGIN
		IF (@StageTypeId = 1) --TTO
		BEGIN			
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, NULL, NULL)
		END

		IF (@StageTypeId IN (2,3)) --PNTA
		BEGIN			
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, 2, @ServiceHeaderId)
		END

		IF (@StageTypeId = 4) --PVLO
		BEGIN	
			SELECT	@TimeLeftover = MIN(TimeLeftover)
			FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServiceElectricPlant](														    	
														@ServiceHeaderId,
														@AirportId,
														2,
														@AircraftTypeCode,
														@GroupTypeEnergy,
														@CompanyId,
														@BillingToCompany,
														NULL,
														NULL,
														@DateService)
				
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, @TimeLeftover, 30.0, 4, @ServiceHeaderId)

		END

		IF (@StageTypeId NOT IN (1,2,3,4)) --OTROS
		BEGIN			
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL)
		END

		RETURN
	END

	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	IF (@CompanyId = 80 AND @BillingToCompany = 164) --GLOBAL AIR A COLOMBIAN AVIATION ROUTING
	BEGIN	
		INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, NULL, NULL)

		RETURN
	END

	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	IF (@CompanyId = 81 AND @BillingToCompany = 81) --JET SMART 
	BEGIN	
		IF (@StageTypeId = 1) --TTO
		BEGIN			
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, NULL, NULL)
		END

		IF (@StageTypeId IN (2,3)) --PNTA
		BEGIN			
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, 2, @ServiceHeaderId)
		END

		IF (@StageTypeId = 4) --PVLO
		BEGIN
			SELECT	@TimeLeftover = MIN(TimeLeftover)
			FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServiceElectricPlant](														    	
														@ServiceHeaderId,
														@AirportId,
														2,
														@AircraftTypeCode,
														@GroupTypeEnergy,
														@CompanyId,
														@BillingToCompany,
														NULL,
														NULL,
														@DateService)
					
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, @TimeLeftover, 30.0, 4, @ServiceHeaderId)	
		END			    

		IF (@StageTypeId NOT IN (1,2,3,4)) --OTROS
		BEGIN			
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL)
		END

		RETURN
	END

	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	IF (@CompanyId = 51 AND @BillingToCompany = 51 AND @DateService >= '2020-02-01') --LANCO
	BEGIN
		IF(@DateService >= '2023-03-03')
		BEGIN
			IF (@AirportId = 5)
			BEGIN
				IF (@StageTypeId = 1) --TTO
				BEGIN			
					INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 150, 30.0, NULL, NULL)
				END	    

				IF (@StageTypeId NOT IN (1)) --OTROS
				BEGIN			
					INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL)
				END

				RETURN
			END
		END

		IF (@StageTypeId = 1) --TTO
		BEGIN			
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 30.0, NULL, NULL)
		END	    

		IF (@StageTypeId NOT IN (1)) --OTROS
		BEGIN			
			INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL)
		END

		RETURN
	END

	------------------------------------------------------------------------------------------------------------
	--**********************************************************************************************************
	------------------------------------------------------------------------------------------------------------
	IF (@CompanyId = 228 AND @BillingToCompany = 228) --GRAN COLOMBIA DE AVIACION (GCA) A GRAN COLOMBIA DE AVIACION (GCA)
	BEGIN
		IF (@DateService >= '2020-12-02')
		BEGIN
			IF (@AirportId IN (18, 51)) --CUC, RCH
			BEGIN
				IF (@StageTypeId = 1) --TTO
				BEGIN			
					INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, NULL, NULL)
				END	    

				IF (@StageTypeId NOT IN (1)) --OTROS
				BEGIN			
					INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL)
				END
			END
			ELSE
			BEGIN
				INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL)
			END
		END

		RETURN
	END

	-- =============================================
	-- VIVAAEROBUS FULL HANDLING
	-- =============================================
	IF (@CompanyId = 255 AND @BillingToCompany = 255)
	BEGIN
		IF (@DateService >= '2021-08-21')
		BEGIN
			SET @TimeLeftover = NULL --OJO!! NECESARIO PARA VALIDACIONES MAS ABAJO

			IF (@DateService >= '2021-08-21' AND @AirportId = 12) --BOG
			BEGIN
				IF (@StageTypeId = 1) --PARA TRANSITO
				BEGIN
					IF ([CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_RemoteGateArrival](@ServiceHeaderId) = 0)
					BEGIN
						SET @ExtraText = 'POSICION MUELLE'
						SET @TimeLeftover = 0 --En muelles en BOG no se incluye nada de planta por el manejo con OPAIN
					END
					ELSE
					BEGIN
						SET @ExtraText = 'POSICION REMOTA'
						SET @TimeLeftover = 90 --En posiciones remotas en BOG se incluyen 90 minutos de planta
					END
				END
				ELSE
				BEGIN
					SET @TimeLeftover = 0 --No existe en los contrato de manera explícita el modelo con pernocta
				END
			END

			IF (@DateService >= '2022-04-08' AND @AirportId = 3) --MDE
			BEGIN
				IF (@StageTypeId = 1) --PARA TRANSITO
				BEGIN
					SET @TimeLeftover = 90 --Se incluyen 90 minutos de planta en MDE
				END
				ELSE
				BEGIN
					SET @TimeLeftover = 0 --No existe en los contrato de manera explícita el modelo con pernocta
				END
			END
			
			IF (@TimeLeftover IS NULL)
			BEGIN
				SET @ExtraText = 'AEROPUERTO ALTERNO'
				SET @TimeLeftover = 0 --Para los aeropuertos alternos no se incluye nada de planta
			END		

			IF (@TimeLeftover > 0) --SI HAY TIEMPO INCLUIDO FILTRAN ESOS MINUTOS PRIMERO PARA PODER REALIZAR LOS OTROS CALCULOS DE LAS FRACCIONES A COBRAR
			BEGIN
				DELETE	@ServiceDetailFiltered
				INSERT	@ServiceDetailFiltered
				SELECT	RowNumber, Service, StartTime, EndTime, TotalTime, Quantity
				FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges_V2(@ServiceDetail, @TimeLeftover, NULL, '*', NULL) --SE FILTRAN SOLAMENTE LOS TIEMPOS DESDE EL MINUTO 91 EN ADELANTE

				DELETE	@ServiceDetail
				INSERT	@ServiceDetail
				SELECT	Fila, Servicio, HoraInicio, HoraFinal, TiempoTotal, Cantidad
				FROM	@ServiceDetailFiltered

				DELETE	@ServiceDetailFiltered
			END

			SET @ServiceGPUTime = (SELECT SUM(TiempoTotal) FROM @ServiceDetail) --Se recalcula el tiempo basado en el resultado filtrado

			IF (@ServiceGPUTime > 0 AND @ServiceGPUTime <= 60)
			BEGIN
				INSERT  @T_Result
				SELECT	StartDate
					,	EndDate
					,	Time
					,	AdditionalService
					,	AdditionalStartTime
					,	AdditionalEndTime
					,	AdditionalTime
					,	AdditionalQuanty
					,	CONCAT(AdditionalServiceName, ' ', @ExtraText) AdditionalServiceName
					,	FractionName
					,	TimeLeftover
					,	NULL CostCenter
				FROM    [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetail, 0, 30.0, '*', @ServiceHeaderId) --OJO NUEVA VERSION DE LA FUNCION
				WHERE	AdditionalService = 1
			END

			IF (@ServiceGPUTime > 60)
			BEGIN
				INSERT		@T_Result
				SELECT		R.StartTime,
							R.EndTime,
							CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END Time,
							1 AdditionalService,
							R.StartTime AdditionalStartTime,
							R.EndTime AdditionalEndTime,
							CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END AdditionalTime,
							CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN 1 END AdditionalQuanty,
							CONCAT(FD.FractionName, ' ', R.Service, ' ', @ExtraText) AdditionalServiceName,
							FD.FractionName,
							NULL TimeLeftover,
							NULL CostCenter
				FROM		[CIOReglaNegocio].[ServiceDetailFilterByMinuteRanges_V2](@ServiceDetail, 0, 90, '*', NULL) R
				OUTER APPLY [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_FractionDetail](90) FD --FRACCION DE 90 MINUTOS

				IF (@ServiceGPUTime > 90)
				BEGIN
					DELETE	@ServiceDetailFiltered
					INSERT	@ServiceDetailFiltered
					SELECT	RowNumber, Service, StartTime, EndTime, TotalTime, Quantity
					FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges_V2(@ServiceDetail, 90, NULL, '*', NULL) --SERVICIOS DESDE EL MINUTO 91 EN ADELANTE

					INSERT  @T_Result
					SELECT	StartDate
						,	EndDate
						,	Time
						,	AdditionalService
						,	AdditionalStartTime
						,	AdditionalEndTime
						,	AdditionalTime
						,	AdditionalQuanty
						,	CONCAT(AdditionalServiceName, ' ', @ExtraText) AdditionalServiceName
						,	FractionName
						,	TimeLeftover
						,	NULL CostCenter
					FROM    [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetailFiltered, 0, 30.0, '*', @ServiceHeaderId) --OJO NUEVA VERSION DE LA FUNCION
					WHERE	AdditionalService = 1
				END
			END

			RETURN
		END

		RETURN
	END

	------------------------------------------------------------------------------------------------------------
	--***************************************************************************************OTROS OTROS OTROS**
	------------------------------------------------------------------------------------------------------------
    --DRUMMOND, LC PERÚ ETC...
	INSERT @T_Result SELECT StartDate, EndDate, Time, AdditionalService, AdditionalStartTime, AdditionalEndTime, AdditionalTime, AdditionalQuanty, AdditionalServiceName, FractionName, TimeLeftover, NULL CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL, NULL)

	RETURN

END